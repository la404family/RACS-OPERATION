if (!isServer) exitWith {};

[] spawn {
    // Attendre que la position de l'intro soit déterminée et le camion placé
    private _lzPos = [0,0,0];
    waitUntil {
        sleep 0.5;
        _lzPos = missionNamespace getVariable ["MISSION_intro_lz", [0,0,0]];
        _lzPos isNotEqualTo [0,0,0]
    };

    private _veh = missionNamespace getVariable ["vehicule_team", objNull];
    waitUntil {
        sleep 0.5;
        !isNull _veh && { _veh distance2D _lzPos < 100 }
    };

    // Laisser le camion s'immobiliser
    sleep 1;

    // Positionner la caisse à l'avant droite du camion
    // modelToWorld [X, Y, Z] : X = droite (+2.5m), Y = avant (+4.5m)
    private _pos = _veh modelToWorld [2.5, 4.5, 0];
    _pos set [2, 0]; // S'assurer qu'elle est bien au niveau du sol

    // Créer la caisse d'arsenal (elle sera ainsi visible dès la scène finale de l'intro !)
    private _crate = createVehicle ["B_supplyCrate_F", _pos, [], 0, "CAN_COLLIDE"];
    _crate setDir (getDir _veh);
    _crate setPos _pos;

    // Vider le contenu physique initial
    clearWeaponCargoGlobal _crate;
    clearMagazineCargoGlobal _crate;
    clearItemCargoGlobal _crate;
    clearBackpackCargoGlobal _crate;

    // Récupérer dynamiquement toutes les armes configurées dans le jeu (Primaires, Secondaires/Lanceurs, Handguns/Tertiaires)
    private _allWeapons = [];
    private _cfgWeapons = configFile >> "CfgWeapons";
    
    {
        private _weaponName = configName _x;
        private _scope = getNumber (_x >> "scope");
        private _type = getNumber (_x >> "type");
        if (_scope == 2 && { _type in [1, 2, 4] }) then {
            _allWeapons pushBack _weaponName;
        };
    } forEach ("true" configClasses _cfgWeapons);

    // Initialiser l'arsenal en mode restreint (false) puis ajouter UNIQUEMENT les armes
    ["AmmoboxInit", [_crate, false]] call BIS_fnc_arsenal;
    [_crate, _allWeapons, true] call BIS_fnc_addVirtualWeaponCargo;

    // Créer un marqueur jaune sur la carte avec le type "mil_box"
    private _mkrName = "mkr_start_arsenal";
    createMarker [_mkrName, _pos];
    _mkrName setMarkerType "mil_box";
    _mkrName setMarkerColor "ColorYellow";

    // Premier fumigène rouge pour que la caisse fume pendant l'introduction (Landing Zone)
    private _introSmoke = "SmokeShellRed" createVehicle _pos;
    _introSmoke attachTo [_crate, [0, 0, 0.4]];

    // Deuxième fumigène rouge déclenché dès la fin de l'intro pour que la caisse fume de façon fraîche quand les joueurs prennent le contrôle
    [_crate, _pos] spawn {
        params ["_crate", "_pos"];
        waitUntil {
            sleep 0.5;
            missionNamespace getVariable ["MISSION_intro_finished", false]
        };
        if (!isNull _crate) then {
            private _startSmoke = "SmokeShellRed" createVehicle _pos;
            _startSmoke attachTo [_crate, [0, 0, 0.4]];
        };
    };

    // Boucle de timer de 20 minutes (1200 secondes) avec mise à jour du marqueur
    private _duration = 1200;
    private _endTime = time + _duration;

    while { time < _endTime && !isNull _crate } do {
        private _timeLeft = round (_endTime - time);
        if (_timeLeft < 0) then { _timeLeft = 0; };
        private _mins = floor (_timeLeft / 60);
        private _secs = _timeLeft mod 60;
        
        private _timeStr = format ["%1:%2", if (_mins < 10) then {"0"+str _mins} else {str _mins}, if (_secs < 10) then {"0"+str _secs} else {str _secs}];
        
        // Sécurité si la table des chaînes (stringtable) n'a pas été rechargée par l'éditeur
        private _localizedText = localize "STR_LL_StartArsenal_Marker";
        if (_localizedText == "" || _localizedText == "STR_LL_StartArsenal_Marker") then {
            _localizedText = "PREPARATIFS (Arsenal)";
        };
        private _mkrText = format ["%1 - %2", _localizedText, _timeStr];
        
        _mkrName setMarkerText _mkrText;
        sleep 1;
    };

    // Supprimer le marqueur de la carte
    deleteMarker _mkrName;

    // Phase de disparition avec effet de fumée identique aux IEDs (Task 02)
    if (!isNull _crate) then {
        private _cratePos = getPosATL _crate;
        
        // Même effet de particules local sur tous les clients que le désamorçage d'IED
        [[_cratePos], {
            params ["_pos"];
            [_pos] spawn {
                params ["_pos"];
                private _emitter = "#particlesource" createVehicleLocal _pos;
                _emitter setParticleCircle [0.1, [0.1, 0.1, 0]];
                _emitter setParticleRandom [2, [0.4, 0.4, 0.2], [0.5, 0.5, 0.3], 1, 0.2, [0, 0, 0, 0.05], 0, 0];
                _emitter setParticleParams [
                    ["\A3\data_f\ParticleEffects\Universal\Universal", 16, 7, 48, 1], "", "Billboard",
                    1, 8, [0, 0, 0.1], [0, 0, 0.4], 0, 1.27, 1, 0.05,
                    [1, 3.5, 6.5], 
                    [[0.9, 0.9, 0.9, 0.85], [0.95, 0.95, 0.95, 0.55], [0.95, 0.95, 0.95, 0]],
                    [0.5], 0.1, 0, "", "", _emitter
                ];
                _emitter setDropInterval 0.005; 
                sleep 2; 
                deleteVehicle _emitter;
            };
        }] remoteExec ["spawn", 0];
        
        sleep 1; // Laisser le temps à l'effet de s'afficher
        
        // Supprimer proprement l'arsenal et la caisse
        ["AmmoboxExit", [_crate]] call BIS_fnc_arsenal;
        deleteVehicle _crate;
    };
};
