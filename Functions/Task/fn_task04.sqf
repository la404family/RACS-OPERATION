params [["_mode", "init", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {};

if (_mode == "init") exitWith {
    private _allLogics = [];
    {
        if ((_x select [0, 9]) == "Heliport_") then {
            private _obj = missionNamespace getVariable [_x, objNull];
            if (!isNull _obj) then { _allLogics pushBack _obj; };
        };
    } forEach (allVariables missionNamespace);
    if (count _allLogics < 1) exitWith {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then { diag_log "[LL] task04 ERROR: Pas de Heliport_ trouvé."; };
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    };

    private _numTrucks = 2 + floor(random 2); // 2 ou 3 camions
    private _selectedLogics = [];
    private _alivePlayers = allPlayers select { alive _x };
    private _logicsPool = _allLogics call BIS_fnc_arrayShuffle;
    
    // Sélectionner les emplacements espacés d'au moins 250m des joueurs et entre eux
    {
        private _candidate = _x;
        private _candidatePos = getPosASL _candidate;
        private _valid = true;
        { if (_x distance2D _candidatePos < 250) exitWith { _valid = false; }; } forEach _alivePlayers;
        { if (_x distance2D _candidatePos < 250) exitWith { _valid = false; }; } forEach _selectedLogics;
        if (_valid) then { _selectedLogics pushBack _candidate; };
        if (count _selectedLogics == _numTrucks) exitWith {};
    } forEach _logicsPool;
    
    // Fallback à 100m si on n'a pas pu en placer assez
    if (count _selectedLogics < _numTrucks) then {
        {
            private _candidate = _x;
            if !(_candidate in _selectedLogics) then {
                private _candidatePos = getPosASL _candidate;
                private _valid = true;
                { if (_x distance2D _candidatePos < 150) exitWith { _valid = false; }; } forEach _alivePlayers;
                { if (_x distance2D _candidatePos < 100) exitWith { _valid = false; }; } forEach _selectedLogics;
                if (_valid) then { _selectedLogics pushBack _candidate; };
            };
            if (count _selectedLogics == _numTrucks) exitWith {};
        } forEach _logicsPool;
    };

    if (count _selectedLogics < 1) exitWith {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then { diag_log "[LL] task04 ERROR: Impossible de trouver un Heliport_ valide. Relance dans 15s."; };
        [[], "LL_fnc_task04"] spawn { sleep 15; ["init"] spawn LL_fnc_task04; };
    };

    missionNamespace setVariable ["LL_Task04_RemainingTrucks", [], true];
    missionNamespace setVariable ["LL_Task04_AllUnits", [], true];
    missionNamespace setVariable ["LL_Task04_Failed", false, true];

    private _allTrucks = [];
    private _allUnits = [];

    {
        private _selectedLogic = _x;
        private _spawnPos = getPosASL _selectedLogic;
        _spawnPos set [2, (_spawnPos select 2) + 0.2];

        // --- Spawn Gardes (OPFOR) ---
        // Nombre de gardes aléatoire (3 à 6 par camion)
        private _numGuards = 3 + floor(random 4); 
        private _guardsLeft = _numGuards;
        
        while { _guardsLeft > 0 } do {
            private _grpSize = (2 + floor(random 2)) min _guardsLeft;
            private _grpOpfor = createGroup [east, true];
            _grpOpfor setBehaviour "SAFE";
            
            for "_g" from 1 to _grpSize do {
                sleep 0.7;
                private _guardClass = selectRandom ["CUP_O_TK_Soldier", "CUP_O_TK_Soldier_GL", "CUP_O_TK_Soldier_AR"];
                private _patrolPos = _spawnPos getPos [10 + random 15, random 360];
                private _guard = _grpOpfor createUnit [_guardClass, _patrolPos, [], 0, "NONE"];
                _guard allowDamage false;
                [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };
                _allUnits pushBack _guard;
            };
            
            // Patrouille locale aléatoire autour du spawn
            private _wp = _grpOpfor addWaypoint [_spawnPos, 25];
            _wp setWaypointType "MOVE";
            _wp setWaypointBehaviour "SAFE";
            _wp setWaypointSpeed "LIMITED";
            private _wp2 = _grpOpfor addWaypoint [_spawnPos, 25];
            _wp2 setWaypointType "MOVE";
            private _wp3 = _grpOpfor addWaypoint [_spawnPos, 20];
            _wp3 setWaypointType "CYCLE";
            
            _guardsLeft = _guardsLeft - _grpSize;
        };

        // --- Spawn Camion Chimique ---
        sleep 0.7;
        private _truckClasses = ["CUP_O_V3S_Refuel_TKA", "CUP_O_Ural_Refuel_TKA", "CUP_I_T810_Refuel_LDF"];
        private _truck = createVehicle [selectRandom _truckClasses, _spawnPos, [], 0, "CAN_COLLIDE"];
        _truck setPosASL _spawnPos;
        _truck setDir (random 360);
        
        // Bloquer le camion pour qu'il soit immobile
        _truck setFuel 0;
        
        _allTrucks pushBack _truck;
        _allUnits pushBack _truck;

        // --- Gestion Fumée Toxique & Dégâts ---
        _truck addEventHandler ["HandleDamage", {
            params ["_unit", "_selection", "_damage"];
            if (!alive _unit) exitWith { _damage };
            
            private _currentDmg = damage _unit;
            private _newDmg = _currentDmg max _damage;
            
            private _level = (floor (_newDmg * 10)) min 9;
            if (_level >= 1) then {
                _unit setVariable ["LL_Toxic_Level", _level max (_unit getVariable ["LL_Toxic_Level", 0]), true];
                private _emitter = _unit getVariable ["LL_Toxic_Smoke1", objNull];
                if (isNull _emitter) then {
                    _emitter = "#particlesource" createVehicleLocal (getPos _unit);
                    _unit setVariable ["LL_Toxic_Smoke1", _emitter];
                    
                    // Boucle de dégâts persistante et mise à jour dynamique (max 10 minutes avec réduction lente)
                    [_unit] spawn {
                        params ["_truck"];
                        private _startTime = time;
                        while { alive _truck && !isNull (_truck getVariable ["LL_Toxic_Smoke1", objNull]) } do {
                            private _elapsed = time - _startTime;
                            private _emitter = _truck getVariable ["LL_Toxic_Smoke1", objNull];
                            
                            if (_elapsed >= 600) exitWith {
                                if (!isNull _emitter) then { deleteVehicle _emitter; };
                                _truck setVariable ["LL_Toxic_Smoke1", objNull];
                            };
                            
                            private _timeFactor = (1 - (_elapsed / 600)) max 0;
                            private _lvl = _truck getVariable ["LL_Toxic_Level", 0];
                            
                            if (_lvl >= 1 && !isNull _emitter) then {
                                private _radius = (4 + (_lvl * 0.8)) * _timeFactor;
                                private _dmg = (0.0015 * _lvl) * _timeFactor;
                                
                                {
                                    if (alive _x && _x distance2D _truck < _radius) then {
                                        _x setDamage ((damage _x) + _dmg);
                                    };
                                } forEach allUnits;
                                
                                // Débit de fumée réduit progressivement
                                private _dropInterval = (0.35 / _lvl) / (_timeFactor max 0.05);
                                _emitter setDropInterval _dropInterval;
                                
                                // Ajustement de la taille (plus fine), de la dispersion et de la transparence (très diffuse)
                                private _sizeMultiplier = (1 + (_lvl * 0.15)) * _timeFactor;
                                _emitter setParticleParams [
                                    ["\A3\data_f\ParticleEffects\Universal\Universal", 16, 7, 48, 1], "", "Billboard", 1, 12,
                                    [0, 0, 0.2], [0, 0, 0.3], 0, 1.28, 1, 0.05, [1.5 * _sizeMultiplier, 3 * _sizeMultiplier, 5 * _sizeMultiplier],
                                    [[0.6, 0.7, 0.2, 0.25 * _timeFactor], [0.5, 0.6, 0.15, 0.15 * _timeFactor], [0.4, 0.5, 0.1, 0]], [0.125], 1, 0, "", "", _truck
                                ];
                                _emitter setParticleRandom [3, [2, 2, 0.2], [0.8, 0.8, 0.3], 1, 0.3, [0, 0, 0, 0.05], 0, 0];
                            };
                            sleep 1;
                        };
                    };
                };
            };
            
            _damage
        }];

        _truck setHitPointDamage ["HitEngine", 1];

        // Explosion du camion = ECHEC
        _truck addEventHandler ["Killed", {
            params ["_unit"];
            if (missionNamespace getVariable ["LL_Task04_Failed", false]) exitWith {};
            missionNamespace setVariable ["LL_Task04_Failed", true, true];

            ["task_04_convoy", "FAILED", true] call BIS_fnc_taskSetState;
            missionNamespace setVariable ["LL_g_taskInProgress", false, true];
            
            // Supprimer tous les marqueurs
            private _remaining = missionNamespace getVariable ["LL_Task04_RemainingTrucks", []];
            {
                private _mkr = _x getVariable ["LL_Task04_Marker", ""];
                if (_mkr != "") then { deleteMarker _mkr; };
            } forEach _remaining;

            // Nettoyage asynchrone des autres camions restants lorsqu'ils sont à plus de 800m
            {
                private _t = _x;
                if (!isNull _t && _t != _unit) then {
                    [_t] spawn {
                        params ["_t"];
                        waitUntil {
                            sleep 5;
                            isNull _t || !alive _t || ({ _x distance2D _t <= 800 } count (allPlayers select { alive _x })) == 0
                        };
                        if (!isNull _t) then {
                            private _emitter = _t getVariable ["LL_Toxic_Smoke1", objNull];
                            if (!isNull _emitter) then { deleteVehicle _emitter; };
                            deleteVehicle _t;
                        };
                    };
                };
            } forEach _remaining;

            // Explosion de gaz toxique diffuse
            private _pos = getPos _unit;
            private _emitter = "#particlesource" createVehicle _pos;
            _emitter setParticleParams [
                ["\A3\data_f\ParticleEffects\Universal\Universal", 16, 7, 48, 1], "", "Billboard", 1, 30,
                [0, 0, 0.5], [0, 0, 0.5], 0, 1.28, 1, 0.05, [3, 10, 18],
                [[0.7, 0.8, 0.2, 0.35], [0.6, 0.7, 0.15, 0.2], [0.4, 0.5, 0.1, 0]], [0.125], 1, 0, "", "", _unit
            ];
            _emitter setParticleRandom [8, [8, 8, 0.5], [1, 1, 0.2], 2, 0.6, [0, 0, 0, 0.05], 0, 0];
            _emitter setDropInterval 0.035;

            // Boucle de dégâts toxiques : les unités à moins de 30m prennent des dégâts sur la durée (40 secondes)
            [_pos] spawn {
                params ["_pos"];
                for "_i" from 1 to 40 do {
                    {
                        if (alive _x && _x distance2D _pos < 30) then {
                            private _damage = damage _x;
                            _x setDamage (_damage + 0.10); // 10% de dégâts par seconde dans le nuage
                        };
                    } forEach allUnits; // On cible les joueurs et les PNJ
                    sleep 1;
                };
            };

            // Fuite des gardes survivants (Dissolution)
            private _allUnits = missionNamespace getVariable ["LL_Task04_AllUnits", []];
            private _guards = _allUnits select { alive _x && _x isKindOf "Man" };
            if (count _guards > 0) then {
                private _dissolveGrp = createGroup [east, true];
                { 
                    _x enableAI "MOVE"; _x setBehaviour "SAFE"; _x setSpeedMode "FULL"; 
                    _x setVariable ["LL_TaskXX_Escaping", true, true]; 
                } forEach _guards;
                _guards joinSilent _dissolveGrp;
                
                [_guards, _dissolveGrp] spawn {
                    params ["_units", "_grp"];
                    private _alive = _units select { alive _x };
                    if (count _alive == 0) exitWith {};
                    private _running = true;
                    while { _running && ({ alive _x } count _alive) > 0 } do {
                        private _refPos  = getPos (leader _grp);
                        private _dissolvePos = [];
                        private _attempts    = 0;
                        while { count _dissolvePos == 0 && _attempts < 30 } do {
                            _attempts = _attempts + 1;
                            private _candidate = _refPos getPos [200 + random 300, random 360];
                            private _valid = true;
                            { if (_x distance2D _candidate <= 150) exitWith { _valid = false; }; } forEach (allPlayers select { alive _x });
                            if (_valid) then { _dissolvePos = _candidate; };
                        };
                        if (count _dissolvePos == 0) then { _dissolvePos = _refPos getPos [400, random 360]; };
                        while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                        private _wp = _grp addWaypoint [_dissolvePos, 5];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointSpeed "FULL";
                        _wp setWaypointBehaviour "SAFE";
                        waitUntil { sleep 1; ({ alive _x } count _alive) == 0 || (leader _grp distance2D _dissolvePos <= 5) };
                        if (({ alive _x } count _alive) == 0) exitWith { _running = false; };
                        private _allFar = true;
                        { if (_x distance2D _dissolvePos <= 150) exitWith { _allFar = false; }; } forEach (allPlayers select { alive _x });
                        if (_allFar) then {
                            { if (!isNull _x && alive _x) then { deleteVehicle _x; }; } forEach _alive;
                            if (!isNull _grp) then { deleteGroup _grp; };
                            _running = false;
                        };
                    };
                };
            };
        }];

        // --- Création Marqueur ---
        private _idx = count _allTrucks;
        private _mkrName = format ["mkr_task04_truck_%1", _idx];
        createMarker [_mkrName, getPosASL _truck];
        _mkrName setMarkerType "o_support";
        _mkrName setMarkerColor "ColorOrange";
        _mkrName setMarkerText (format ["%1 (%2/%3)", localize "STR_LL_Task_04_MarkerMain", _idx, _numTrucks]);
        
        _truck setVariable ["LL_Task04_Marker", _mkrName, true];

        // Attacher l'action au client pour ce camion spécifique
        [_truck] remoteExec ["LL_fnc_task04_addAction", 0, true];

    } forEach _selectedLogics;

    missionNamespace setVariable ["LL_Task04_RemainingTrucks", _allTrucks, true];
    missionNamespace setVariable ["LL_Task04_AllUnits", _allUnits, true];

    // --- Création de la Tâche unique ---
    [
        independent,
        ["task_04_convoy"],
        [
            localize "STR_LL_Task_04_Desc",
            localize "STR_LL_Task_04_Title",
            ""
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "danger",
        false
    ] call BIS_fnc_taskCreate;

    [[], { player createDiaryRecord ["diary", [localize "STR_LL_Diary_Task04_Title", localize "STR_LL_Diary_Task04_Text"]]; }] remoteExec ["spawn", 0, true];

    ["STR_LL_Task_Assigned"] remoteExec ["LL_fnc_radioMessage", 0];
};

if (_mode == "extract") exitWith {
    _args params ["_truck", "_caller"];

    if (!alive _truck) exitWith {};

    ["STR_LL_Heli_Dispatch_Approve_EMBARQUEMENT"] remoteExec ["LL_fnc_radioMessage", 0];

    // --- Script d'Extraction Slingload Cinématique ---
    [_truck] spawn {
        params ["_cargo"];
        
        private _spawnPosHeli = (getPos _cargo) getPos [2500, random 360];
        _spawnPosHeli set [2, 150];
        
        private _dropPos = _spawnPosHeli getPos [3000, random 360];
        _dropPos set [2, 150];

        // Spawn de l'Hélico allié
        private _grp = createGroup [independent, true];
        private _heli = createVehicle ["CUP_I_UH60L_FFV_RACS", _spawnPosHeli, [], 0, "FLY"];
        _heli setPosASL _spawnPosHeli;
        
        private _pilot = _grp createUnit ["CUP_I_RACS_Pilot", _spawnPosHeli, [], 0, "NONE"];
        _pilot moveInDriver _heli;
        private _copilot = _grp createUnit ["CUP_I_RACS_Pilot", _spawnPosHeli, [], 0, "NONE"];
        _copilot moveInTurret [_heli, [0]];
        
        _heli allowDamage false; // Sécurité pour éviter que l'IA crash stupidement
        _grp setBehaviour "CARELESS"; // Empêche l'évitement de combat
        _grp setCombatMode "BLUE";
        
        { _x disableAI "FSM"; _x disableAI "TARGET"; _x disableAI "AUTOTARGET"; } forEach [_pilot, _copilot];
        _heli disableCollisionWith _cargo;
        _cargo disableCollisionWith _heli;

        // Nettoyage waypoints
        while { count (waypoints _grp) > 0 } do { deleteWaypoint [_grp, 0]; };

        // === Phase 1 : Approche ===
        private _targetPos = getPos _cargo;
        private _hoverHeight = 15;
        _heli flyInHeight _hoverHeight;
        _heli flyInHeightASL [_hoverHeight, _hoverHeight, _hoverHeight];

        private _wp = _grp addWaypoint [_targetPos, 0];
        _wp setWaypointType      "MOVE";
        _wp setWaypointBehaviour "CARELESS";
        _wp setWaypointSpeed     "FULL";
        _heli doMove _targetPos;

        private _apTimer = 0;
        waitUntil {
            sleep 0.5; _apTimer = _apTimer + 0.5;
            (_heli distance2D _targetPos < 15) || _apTimer > 120 || !alive _heli || !alive _cargo
        };
        
        while { count (waypoints _grp) > 0 } do { deleteWaypoint [_grp, 0]; };
        
        if (!alive _heli || !alive _cargo) exitWith {};

        // === Phase 2 : Descente maîtrisée ===
        doStop _heli;
        private _minH        = 9.5;
        private _heliThresh  = 10;
        private _descTimer   = 0;

        waitUntil {
            sleep 0.5; _descTimer = _descTimer + 0.5;
            private _newH = (_hoverHeight - _descTimer) max _minH;
            _heli flyInHeight _newH;
            _heli flyInHeightASL [_newH, _newH, _newH];
            private _heliH = getPosATL _heli select 2;
            _heliH < _heliThresh || _descTimer > 30 || !alive _heli || !alive _cargo
        };

        if (!alive _heli || !alive _cargo) exitWith {};

        // === Phase 3 : Attache (SlingLoad) ===
        _cargo setMass 1000; 
        
        sleep 0.5;
        _heli setSlingLoad _cargo;
        sleep 2;
        if (isNull (getSlingLoad _heli)) then {
            _heli setSlingLoad _cargo;
        };
        
        // === Phase 4 : Vol vers drop (Succès) ===
        _heli flyInHeight 50;
        _heli flyInHeightASL [50, 50, 50];
        
        _wp = _grp addWaypoint [_dropPos, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "NORMAL";
        _heli doMove _dropPos;

        // Mise à jour de la liste des camions restants
        private _remaining = missionNamespace getVariable ["LL_Task04_RemainingTrucks", []];
        _remaining = _remaining - [_cargo];
        missionNamespace setVariable ["LL_Task04_RemainingTrucks", _remaining, true];

        // Supprimer le marqueur de ce camion
        private _mkr = _cargo getVariable ["LL_Task04_Marker", ""];
        if (_mkr != "") then { deleteMarker _mkr; };

        // Si tous les camions sont extraits = SUCCÈS
        if (count _remaining == 0) then {
            ["task_04_convoy", "SUCCEEDED", true] call BIS_fnc_taskSetState;
            missionNamespace setVariable ["LL_g_taskInProgress", false, true];
        };

        // Attente arrivée + largage et nettoyage
        waitUntil { sleep 1; _heli distance2D _dropPos < 150 };
        _heli setSlingLoad objNull;
        sleep 2;
        
        // Nettoyage à plus de 800m des joueurs (règle utilisateur)
        waitUntil {
            sleep 1;
            private _players = allPlayers select { alive _x };
            ({ _x distance2D _cargo <= 800 } count _players) == 0
        };
        deleteVehicle _cargo; // Le camion disparait de la zone de jeu
        
        sleep 5;
        { deleteVehicle _x; } forEach crew _heli;
        deleteVehicle _heli;
        deleteGroup _grp;
    };
};
