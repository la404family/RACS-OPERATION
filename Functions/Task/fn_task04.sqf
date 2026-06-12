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

    private _logicsPool = _allLogics call BIS_fnc_arrayShuffle;
    private _alivePlayers = allPlayers select { alive _x };
    private _selectedLogic = objNull;

    {
        private _candidate = _x;
        private _candidatePos = getPosASL _candidate;
        private _valid = true;
        { if (_x distance2D _candidatePos < 250) exitWith { _valid = false; }; } forEach _alivePlayers;
        if (_valid) exitWith { _selectedLogic = _candidate; };
    } forEach _logicsPool;

    if (isNull _selectedLogic) exitWith {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then { diag_log "[LL] task04 ERROR: Impossible de trouver un Heliport_ à >250m. Relance dans 15s."; };
        [[], "LL_fnc_task04"] spawn { sleep 15; ["init"] spawn LL_fnc_task04; };
    };

    missionNamespace setVariable ["LL_Task04_AllUnits", [], true];
    private _allUnits = [];

    private _spawnPos = getPosASL _selectedLogic;
    _spawnPos set [2, (_spawnPos select 2) + 0.2];

    // --- Spawn Gardes (OPFOR) ---
    // 4 à 8 unités en groupes de 2 ou 3
    private _numGuards = 4 + floor(random 5); 
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
    _truck setHitPointDamage ["HitEngine", 1];
    
    missionNamespace setVariable ["LL_Task04_Truck", _truck, true];
    _allUnits pushBack _truck;
    missionNamespace setVariable ["LL_Task04_AllUnits", _allUnits, true];

    // --- Gestion Fumée Toxique & Dégâts ---
    _truck addEventHandler ["HandleDamage", {
        params ["_unit", "_selection", "_damage"];
        if (!alive _unit) exitWith { _damage };
        
        private _currentDmg = damage _unit;
        private _newDmg = _currentDmg max _damage;
        
        // Niveau 1 de fuite toxique
        if (_newDmg > 0.2 && isNull (_unit getVariable ["LL_Toxic_Smoke1", objNull])) then {
            private _emitter = "#particlesource" createVehicleLocal (getPos _unit);
            // Paramètres modifiés pour un gaz moutarde/chlore (jaune-vert maladif)
            _emitter setParticleParams [
                ["\A3\data_f\ParticleEffects\Universal\Universal", 16, 7, 48, 1], "", "Billboard", 1, 15,
                [0, 0, 0], [0, 0, 0], 0, 1.28, 1, 0.05, [4, 10, 18],
                [[0.6, 0.7, 0.2, 0.7], [0.5, 0.6, 0.15, 0.5], [0.4, 0.5, 0.1, 0]], [0.125], 1, 0, "", "", _unit
            ];
            _emitter setParticleRandom [3, [4, 4, 0], [1, 1, 0.2], 1, 0.5, [0, 0, 0, 0.1], 0, 0];
            _emitter setDropInterval 0.1;
            _unit setVariable ["LL_Toxic_Smoke1", _emitter];
            
            // Boucle de dégâts persistante autour du camion
            [_unit] spawn {
                params ["_truck"];
                while { alive _truck && !isNull (_truck getVariable ["LL_Toxic_Smoke1", objNull]) } do {
                    private _isSevere = _truck getVariable ["LL_Toxic_Smoke2", false];
                    private _radius = if (_isSevere) then { 15 } else { 8 };
                    private _dmg    = if (_isSevere) then { 0.05 } else { 0.02 }; // 5% ou 2% de dégâts/seconde
                    
                    {
                        if (alive _x && _x distance2D _truck < _radius) then {
                            _x setDamage ((damage _x) + _dmg);
                        };
                    } forEach allPlayers;
                    sleep 1;
                };
            };
        };
        
        // Niveau 2 de fuite (Sévère)
        if (_newDmg > 0.6 && !(_unit getVariable ["LL_Toxic_Smoke2", false])) then {
            private _emitter2 = _unit getVariable ["LL_Toxic_Smoke1", objNull];
            if (!isNull _emitter2) then { _emitter2 setDropInterval 0.05; };
            _unit setVariable ["LL_Toxic_Smoke2", true];
        };
        
        _damage
    }];

    // Explosion du camion = ECHEC
    _truck addEventHandler ["Killed", {
        params ["_unit"];
        ["task_04_convoy", "FAILED", true] call BIS_fnc_taskSetState;
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
        
        // Enorme explosion de gaz toxique rampante
        private _pos = getPos _unit;
        private _emitter = "#particlesource" createVehicle _pos;
        _emitter setParticleParams [
            ["\A3\data_f\ParticleEffects\Universal\Universal", 16, 7, 48, 1], "", "Billboard", 1, 40,
            [0, 0, 0], [0, 0, 0], 0, 1.28, 1, 0.05, [8, 25, 45],
            [[0.7, 0.8, 0.2, 0.9], [0.6, 0.7, 0.15, 0.8], [0.4, 0.5, 0.1, 0]], [0.125], 1, 0, "", "", _unit
        ];
        _emitter setParticleRandom [10, [15, 15, 0], [1.5, 1.5, 0.1], 2, 1, [0, 0, 0, 0.1], 0, 0];
        _emitter setDropInterval 0.015;

        // Boucle de dégâts toxiques : les unités à moins de 30m prennent des dégâts sur la durée (40 secondes)
        [_pos] spawn {
            params ["_pos"];
            for "_i" from 1 to 40 do {
                {
                    if (alive _x && _x distance2D _pos < 30) then {
                        private _damage = damage _x;
                        _x setDamage (_damage + 0.10); // 10% de dégâts par seconde dans le nuage
                    };
                } forEach allPlayers; // On cible les joueurs
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
            
            // Logique de dissolution (TASK_RULES §14)
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

    // --- Création Marqueur et Tâche ---
    private _mkrName = "mkr_task04_truck";
    createMarker [_mkrName, getPosASL _truck];
    _mkrName setMarkerType "o_support";
    _mkrName setMarkerColor "ColorOrange";
    _mkrName setMarkerText localize "STR_LL_Task_04_MarkerMain";

    [
        independent,
        ["task_04_convoy"],
        [
            localize "STR_LL_Task_04_Desc",
            localize "STR_LL_Task_04_Title",
            localize "STR_LL_Task_04_MarkerMain"
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

    // Attacher l'action au client
    [_truck] remoteExec ["LL_fnc_task04_addAction", 0, true];
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
        private _hoverHeight = 10;
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
            (_heli distance2D _targetPos < 5) || _apTimer > 30 || !alive _heli || !alive _cargo
        };
        
        while { count (waypoints _grp) > 0 } do { deleteWaypoint [_grp, 0]; };
        
        if (!alive _heli || !alive _cargo) exitWith {};

        // === Phase 2 : Descente maîtrisée ===
        doStop _heli;
        private _minH        = 3;
        private _heliThresh  = 3;
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
        // TRICK MOTEUR : On force la masse du camion pour être sûr que le UH-60L puisse le soulever
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

        // Tâche validée dès que l'hélico est attaché et commence à repartir
        ["task_04_convoy", "SUCCEEDED", true] call BIS_fnc_taskSetState;
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
        deleteMarker "mkr_task04_truck";

        // Attente arrivée + largage et nettoyage
        waitUntil { sleep 1; _heli distance2D _dropPos < 150 };
        _heli setSlingLoad objNull;
        sleep 2;
        deleteVehicle _cargo; // Le camion disparait de la zone de jeu
        
        sleep 5;
        { deleteVehicle _x; } forEach crew _heli;
        deleteVehicle _heli;
        deleteGroup _grp;
    };
};
