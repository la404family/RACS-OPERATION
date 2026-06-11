/*
    LL_fnc_task02
    Serveur uniquement.
    Task 02 : Désamorçage de bombes (IED)
*/
params [["_mode", "init", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {};

if (_mode == "init") exitWith {
    private _allLogics = (allMissionObjects "Logic") select { (vehicleVarName _x) select [0, 11] == "M_Dans_Bat_" };
    if (count _allLogics < 2) exitWith {
        diag_log "[LL] task02 ERROR: Pas assez de M_Dans_Bat_ sur la carte.";
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    };

    private _targetNumZones = 2 + floor (random 3); // 2 à 4
    private _selectedLogics = [];
    private _logicsPool = _allLogics call BIS_fnc_arrayShuffle;
    private _alivePlayers = allPlayers select { alive _x };
    
    {
        private _candidate = _x;
        private _candidatePos = getPosASL _candidate;
        private _valid = true;

        { if (_x distance2D _candidatePos < 250) exitWith { _valid = false; }; } forEach _alivePlayers;

        if (_valid) then {
            { if ((getPosASL _x) distance2D _candidatePos < 250) exitWith { _valid = false; }; } forEach _selectedLogics;
        };

        if (_valid) then { _selectedLogics pushBack _candidate; };
        if (count _selectedLogics >= _targetNumZones) exitWith {};
    } forEach _logicsPool;

    private _numZones = count _selectedLogics;
    if (_numZones < 2) exitWith {
        diag_log "[LL] task02 ERROR: Impossible de trouver 2 lieux à >250m. Relance dans 15s.";
        [[], "LL_fnc_task02"] spawn { sleep 15; ["init"] spawn LL_fnc_task02; };
    };

    missionNamespace setVariable ["LL_Task02_AllUnits", [], true];
    private _allUnits = [];
    private _bombs = [];

    // Boucle de spawn
    for "_i" from 0 to (_numZones - 1) do {
        private _logic = _selectedLogics select _i;
        private _spawnPos = getPosASL _logic;
        _spawnPos set [2, (_spawnPos select 2) + 0.2];

        // Gardes (4 à 8 par zone)
        private _grp = createGroup [east, true];
        _grp setBehaviour "SAFE";
        _grp setCombatMode "RED";
        private _numGuards = 4 + floor (random 5);
        for "_g" from 1 to _numGuards do {
            sleep 0.7;
            private _guardClass = selectRandom ["CUP_O_TK_Soldier", "CUP_O_TK_Soldier_GL", "CUP_O_TK_Soldier_AR"];
            private _guard = _grp createUnit [_guardClass, _spawnPos, [], 0, "NONE"];
            _guard setPosASL _spawnPos;
            _guard allowDamage false;
            [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };
            _allUnits pushBack _guard;
            
            // Patrouille locale (4-25m en AWARE)
            _guard setBehaviour "AWARE";
            private _patrolPos = _spawnPos getPos [4 + random 21, random 360];
            _guard doMove _patrolPos;
        };

        // Marqueurs zone
        private _mkrName = format ["mkr_task02_zone_%1", _i];
        createMarker [_mkrName, _spawnPos getPos [random 50, random 360]];
        _mkrName setMarkerType "hd_unknown";
        _mkrName setMarkerColor "ColorOrange";
        _mkrName setMarkerText format ["%1 %2", localize "STR_LL_Task_02_Marker", _i + 1];

        // Bombe (Petite caisse de grenades avec bip)
        sleep 0.7;
        
        // IMPORTANT : On respecte STRICTEMENT la règle du Z + 0.2 de TASK_RULES.md pour les intérieurs
        // Sans cela, la caisse s'enfonce dans le sol, et la charge posée dessus est engloutie par la géométrie !
        private _bomb = createVehicle ["Box_East_Grenades_F", [0,0,0], [], 0, "CAN_COLLIDE"];
        _bomb setPosASL _spawnPos;
        _bomb setDir (random 360);
        _bomb setVariable ["LL_Bomb_Status", "WAIT", true];
        
        // Eviter la destruction immédiate lors du placement
        _bomb allowDamage false;
        [_bomb] spawn { sleep 3; (_this select 0) allowDamage true; };

        // Ajout de la charge explosive posée sur la caisse
        // On n'utilise PLUS de WeaponHolder car le moteur d'Arma le force à tomber par terre (comme vu sur ta capture) !
        // DemoCharge_F est un prop statique valide dans Eden, on l'utilise directement à la bonne hauteur.
        private _charge = createVehicle ["DemoCharge_F", _spawnPos vectorAdd [0, 0, 1], [], 0, "CAN_COLLIDE"];
        _charge attachTo [_bomb, [0, 0, 0.22]]; // 0.22 est le haut exact du modèle Box_East_Grenades_F
        _charge setVectorUp [0, 0, 1];
        
        // Ajout de la petite lumière clignotante orange (faible intensité)
        private _light = "#lightpoint" createVehicle [0,0,0];
        _light attachTo [_bomb, [0, 0, 0.22]]; // Même hauteur que la charge
        _light setLightColor [1, 0.2, 0]; // Orange rouge
        _light setLightAmbient [0, 0, 0]; // AUCUNE lumière d'ambiance pour ne pas éclairer le bâtiment
        _light setLightUseFlare true;
        _light setLightFlareSize 0.1; // Tout petit flare
        _light setLightFlareMaxDistance 50;
        _light setLightAttenuation [0.1, 0, 100, 100]; // Coupure drastique de la lumière
        _light setLightBrightness 0;

        // Si quelqu'un tire dessus
        _bomb addEventHandler ["Killed", {
            params ["_unit", "_killer", "_instigator", "_useEffects"];
            _unit setVariable ["LL_Bomb_Status", "EXPLODED", true];
            // Explosion physique mortelle
            "Bo_GBU12_LGB" createVehicle (getPos _unit);
        }];

        // Son immersif et clignotement synchronisé
        [_bomb, _light, _charge] spawn {
            params ["_bomb", "_light", "_charge"];
            while { alive _bomb && (_bomb getVariable ["LL_Bomb_Status", "WAIT"]) == "WAIT" } do {
                playSound3D ["A3\Sounds_F\sfx\beep_target.wss", _bomb, false, getPosASL _bomb, 1, 1, 50];
                _light setLightBrightness 0.5; // Toute petite intensité pour une LED
                sleep 0.1;
                _light setLightBrightness 0; // Eteint la lumière
                sleep 1.9;
            };
            
            // Nettoyage de la lumière à la fin (désamorcage ou explosion)
            if (!isNull _light) then { deleteVehicle _light; };
            
            // Si c'est désamorcé, on fait disparaître la charge explosive pour donner un retour visuel clair
            if (alive _bomb && (_bomb getVariable ["LL_Bomb_Status", "WAIT"]) == "DEFUSED") then {
                if (!isNull _charge) then { deleteVehicle _charge; };
            };
        };

        _bombs pushBack _bomb;

        // AddAction client pour désamorcer
        [_bomb] remoteExec ["LL_fnc_task02_addAction", 0, true];
    };

    missionNamespace setVariable ["LL_Task02_AllUnits", _allUnits, true];
    missionNamespace setVariable ["LL_Task02_Bombs", _bombs, true];

    // Création de la tâche
    [
        independent,
        ["task_02_bombs"],
        [
            localize "STR_LL_Task_02_Desc",
            localize "STR_LL_Task_02_Title",
            localize "STR_LL_Task_02_MarkerMain"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "mine",
        false
    ] call BIS_fnc_taskCreate;
    
    // Briefing
    [[], { player createDiaryRecord ["diary", [localize "STR_LL_Diary_Task02_Title", localize "STR_LL_Diary_Task02_Text"]]; }] remoteExec ["spawn", 0, true];

    // Notification
    ["STR_LL_Task_Assigned"] remoteExec ["LL_fnc_radioMessage", 0];

    // Lancement du thread de surveillance
    private _timerMinutes = 25 + floor(random 21); // 25 à 45 minutes
    [_timerMinutes, _bombs, _numZones] spawn {
        params ["_timerMinutes", "_bombs", "_numZones"];
        private _endTime = time + (_timerMinutes * 60);
        private _taskDone = false;

        while { !_taskDone } do {
            sleep 1; // Passage à 1 seconde pour une fluidité du timer
            private _defusedCount = 0;
            private _explodedCount = 0;

            {
                private _status = _x getVariable ["LL_Bomb_Status", "WAIT"];
                if (_status == "DEFUSED") then { _defusedCount = _defusedCount + 1; };
                // On utilise uniquement le statut explicite pour éviter les faux positifs d'objNull
                if (_status == "EXPLODED") then { _explodedCount = _explodedCount + 1; };
            } forEach _bombs;

            // Mise à jour du Timer sur les marqueurs
            private _remaining = round (_endTime - time);
            if (_remaining < 0) then { _remaining = 0; };
            private _mins = floor (_remaining / 60);
            private _secs = _remaining mod 60;
            private _timeStr = format ["%1:%2", if (_mins < 10) then {"0"+str _mins} else {str _mins}, if (_secs < 10) then {"0"+str _secs} else {str _secs}];

            for "_i" from 0 to (_numZones - 1) do {
                private _mkrName = format ["mkr_task02_zone_%1", _i];
                private _bombStatus = (_bombs select _i) getVariable ["LL_Bomb_Status", "WAIT"];
                
                if (_bombStatus == "DEFUSED") then {
                    _mkrName setMarkerText format ["%1 %2 - DESAMORCE", localize "STR_LL_Task_02_Marker", _i + 1];
                    _mkrName setMarkerColor "ColorGreen";
                } else {
                    if (_bombStatus == "EXPLODED") then {
                        _mkrName setMarkerText format ["%1 %2 - DETRUIT", localize "STR_LL_Task_02_Marker", _i + 1];
                        _mkrName setMarkerColor "ColorBlack";
                    } else {
                        _mkrName setMarkerText format ["%1 %2 - %3", localize "STR_LL_Task_02_Marker", _i + 1, _timeStr];
                    };
                };
            };

            // Timer écoulé : on fait sauter les bombes restantes
            if (time > _endTime) then {
                {
                    if ((_x getVariable ["LL_Bomb_Status", "WAIT"]) == "WAIT") then {
                        _x setDamage 1; // Déclenche l'explosion et le status EXPLODED
                    };
                } forEach _bombs;
                sleep 2; // Attendre l'explosion
                _explodedCount = 0;
                {
                    if ((_x getVariable ["LL_Bomb_Status", "WAIT"]) == "EXPLODED" || !alive _x) then { _explodedCount = _explodedCount + 1; };
                } forEach _bombs;
            };

            // Condition de fin
            if ((_defusedCount + _explodedCount) >= _numZones) then {
                _taskDone = true;
                
                // Échec seulement si TOUTES les bombes ont explosé
                if (_explodedCount == _numZones) then {
                    ["task_02_bombs", "FAILED", true] call BIS_fnc_taskSetState;
                } else {
                    ["task_02_bombs", "SUCCEEDED", true] call BIS_fnc_taskSetState;
                };

                missionNamespace setVariable ["LL_g_taskInProgress", false, true];

                // Nettoyage marqueurs
                for "_i" from 0 to (_numZones - 1) do { deleteMarker format ["mkr_task02_zone_%1", _i]; };

                // Dissolution
                private _allUnits = missionNamespace getVariable ["LL_Task02_AllUnits", []];
                private _guards = _allUnits select { alive _x };
                
                if (count _guards > 0) then {
                    private _dissolveGrp = createGroup [east, true];
                    {
                        _x enableAI "MOVE";
                        _x setBehaviour "SAFE";
                        _x setSpeedMode "FULL";
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

                            if (count _dissolvePos == 0) then {
                                _dissolvePos = _refPos getPos [400, random 360];
                            };

                            while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                            private _wp = _grp addWaypoint [_dissolvePos, 5];
                            _wp setWaypointType "MOVE";
                            _wp setWaypointSpeed "FULL";
                            _wp setWaypointBehaviour "SAFE";

                            waitUntil {
                                sleep 1;
                                ({ alive _x } count _alive) == 0 || (leader _grp distance2D _dissolvePos <= 5)
                            };

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
            };
        };
    };
};

if (_mode == "defuse") exitWith {
    _args params ["_bomb", "_caller"];

    if ((_bomb getVariable ["LL_Bomb_Status", "WAIT"]) != "WAIT") exitWith {};
    _bomb setVariable ["LL_Bomb_Status", "DEFUSED", true];

    _bomb removeAllEventHandlers "Killed";
    _bomb allowDamage false;

    // Animation / Message local
    _caller playMove "AinvPknlMstpSnonWnonDnon_medic_1";
    [_caller, "STR_LL_Task_02_Defused"] remoteExec ["systemChat", 0];
};
