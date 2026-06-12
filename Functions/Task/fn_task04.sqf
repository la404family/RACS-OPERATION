params [["_mode", "init", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {};

if (_mode == "init") exitWith {

    private _allLogics = (allMissionObjects "Logic") select { (vehicleVarName _x) select [0, 11] == "M_Dans_Bat_" };
    if (count _allLogics < 1) exitWith {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then { diag_log "[LL] task04 ERROR: Pas de M_Dans_Bat_ trouvé sur la carte."; };
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
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then { diag_log "[LL] task04 ERROR: Impossible de trouver un lieu à >250m. Relance dans 15s."; };
        [[], "LL_fnc_task04"] spawn { sleep 15; ["init"] spawn LL_fnc_task04; };
    };

    missionNamespace setVariable ["LL_Task04_AllUnits", [], true];
    private _allUnits = [];

    private _spawnPos = getPosASL _selectedLogic;
    _spawnPos set [2, (_spawnPos select 2) + 0.2];

    // --- Spawn Gardes (OPFOR) ---
    private _grpOpfor = createGroup [east, true];
    _grpOpfor setBehaviour "AWARE";
    _grpOpfor setCombatMode "RED";
    
    private _numGuards = 6 + floor (random 4);
    for "_g" from 1 to _numGuards do {
        sleep 0.7;
        private _guardClass = selectRandom ["CUP_O_TK_Soldier", "CUP_O_TK_Soldier_GL", "CUP_O_TK_Soldier_AR"];
        private _guard = _grpOpfor createUnit [_guardClass, _spawnPos, [], 0, "NONE"];
        _guard setPosASL _spawnPos;
        _guard allowDamage false;
        [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };
        _allUnits pushBack _guard;

        private _patrolPos = _spawnPos getPos [4 + random 21, random 360];
        _guard doMove _patrolPos;
    };

    // --- Spawn HVT (Civilian group, Officer model) ---
    sleep 0.7;
    private _grpCiv = createGroup [civilian, true];
    private _hvt = _grpCiv createUnit ["CUP_O_TK_Officer", _spawnPos, [], 0, "NONE"];
    _hvt setPosASL _spawnPos;
    _hvt allowDamage false;
    [_hvt] spawn { sleep 3; (_this select 0) allowDamage true; };
    _allUnits pushBack _hvt;

    _hvt setCaptive true;
    removeAllWeapons _hvt;
    removeBackpack _hvt;
    removeAllAssignedItems _hvt;
    
    _hvt setVariable ["LL_Task_Status", "WAIT", true];
    missionNamespace setVariable ["LL_Task04_HVT", _hvt, true];

    // --- Comportement HVT (Figé jusqu'à approche) ---
    _hvt disableAI "MOVE";
    _hvt disableAI "ANIM";
    _hvt setUnitPos "UP";

    [_hvt] spawn {
        params ["_hvt"];
        private _surrendered = false;
        
        while { alive _hvt && (_hvt getVariable ["LL_Task_Status", "WAIT"]) == "WAIT" } do {
            private _players = allPlayers select { alive _x };
            if (count _players > 0) then {
                private _nearest = _players select 0;
                private _minDist = _hvt distance2D _nearest;
                {
                    private _d = _hvt distance2D _x;
                    if (_d < _minDist) then { _minDist = _d; _nearest = _x; };
                } forEach _players;
                
                _hvt setDir (_hvt getDir _nearest);
                _hvt setFormDir (_hvt getDir _nearest);
                
                if (!_surrendered && {(_nearest distance _hvt) <= 5}) then {
                    _surrendered = true;
                    [_hvt, "AmovPercMstpSsurWnonDnon"] remoteExec ["switchMove", 0];
                };
            };
            sleep 2;
        };
    };

    _hvt addEventHandler ["Killed", {
        ["task_04_capture", "FAILED", true] call BIS_fnc_taskSetState;
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    }];

    // --- Marqueur et UI ---
    private _mkrName = "mkr_task04_hvt";
    createMarker [_mkrName, getPosASL _hvt];
    _mkrName setMarkerType "mil_objective";
    _mkrName setMarkerColor "ColorOrange";
    _mkrName setMarkerText localize "STR_LL_Task_04_Marker";

    missionNamespace setVariable ["LL_Task04_AllUnits", _allUnits, true];

    // --- Suivi de marqueur et Nettoyage pré-capture ---
    [_hvt, _mkrName, _allUnits] spawn {
        params ["_hvt", "_mkrName", "_allUnits"];
        while { alive _hvt && missionNamespace getVariable ["LL_g_taskInProgress", false] } do {
            _mkrName setMarkerPos (getPosASL _hvt);
            sleep 2;
        };
        deleteMarker _mkrName;

        if (!alive _hvt && (_hvt getVariable ["LL_Task_Status", "WAIT"]) == "WAIT") then {
            private _guards = _allUnits select { _x != _hvt && alive _x };
            if (count _guards > 0) then {
                private _dissolveGrp = createGroup [east, true];
                _guards joinSilent _dissolveGrp;
                { _x enableAI "MOVE"; _x setBehaviour "SAFE"; _x setSpeedMode "FULL"; } forEach _guards;
                
                [_guards, _dissolveGrp] spawn {
                    params ["_units", "_grp"];
                    sleep 60;
                    { if (!isNull _x && alive _x) then { deleteVehicle _x; }; } forEach _units;
                    if (!isNull _grp) then { deleteGroup _grp; };
                };
            };
        };
    };

    [
        independent,
        ["task_04_capture"],
        [
            localize "STR_LL_Task_04_Desc",
            localize "STR_LL_Task_04_Title",
            localize "STR_LL_Task_04_MarkerMain"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "interact",
        false
    ] call BIS_fnc_taskCreate;

    [[], { player createDiaryRecord ["diary", [localize "STR_LL_Diary_Task04_Title", localize "STR_LL_Diary_Task04_Text"]]; }] remoteExec ["spawn", 0, true];

    ["STR_LL_Task_Assigned"] remoteExec ["LL_fnc_radioMessage", 0];

    // Attacher l'action au client
    [_hvt] remoteExec ["LL_fnc_task04_addAction", 0, true];
};

if (_mode == "capture") exitWith {
    _args params ["_hvt", "_caller"];

    if ((_hvt getVariable ["LL_Task_Status", "WAIT"]) != "WAIT") exitWith {};
    _hvt setVariable ["LL_Task_Status", "CAPTURED", true];

    // Libérer l'HVT
    _hvt enableAI "ANIM";
    [_hvt, ""] remoteExec ["switchMove", 0];

    // Intégrer l'HVT dans le groupe du caller
    [_hvt] joinSilent (group _caller);

    { _hvt enableAI _x; } forEach ["MOVE", "AUTOTARGET", "TARGET"];
    _hvt setUnitPos "UP";
    _hvt setBehaviour "CARELESS";
    _hvt setSpeedMode "LIMITED";
    _hvt setSkill ["courage", 1];
    _hvt allowFleeing 0;
    _hvt setCaptive true; // Reste captif pour ne pas se faire tirer dessus bêtement

    // --- Traque Globale (Tous les OPFOR) ---
    private _allBlufor = allUnits select { side _x == west && alive _x };
    private _allOpfor  = allUnits select { side _x == east && alive _x && _x != _hvt };
    if (count _allOpfor > 0 && count _allBlufor > 0) then {
        private _grpsProcessed = [];
        {
            private _enemy = _x;
            _enemy setBehaviour "COMBAT";
            _enemy setCombatMode "RED";
            _enemy setSpeedMode "FULL";
            { _enemy reveal [_x, 4]; } forEach _allBlufor;

            private _grp = group _enemy;
            if !(_grp in _grpsProcessed) then {
                _grpsProcessed pushBack _grp;
                private _grpPos = getPosATL (leader _grp);
                private _nearest = _allBlufor select 0;
                private _nearestDist = _nearest distance2D _grpPos;
                { private _d = _x distance2D _grpPos; if (_d < _nearestDist) then { _nearestDist = _d; _nearest = _x; }; } forEach _allBlufor;
                (leader _grp) commandMove (getPosATL _nearest);
            };
        } forEach _allOpfor;
    };

    // --- Hélicoptère d'Extraction ---
    ["EMBARQUEMENT", getPos _hvt, _caller, 3] spawn LL_fnc_heliDispatch;

    [_hvt] spawn {
        params ["_hvt"];
        waitUntil {
            sleep 1;
            !alive _hvt || !isNull (missionNamespace getVariable ["LL_HELI_obj", objNull])
        };

        if (alive _hvt) then {
            private _heli = missionNamespace getVariable ["LL_HELI_obj", objNull];
            if (!isNull _heli) then {
                [
                    _heli,
                    [
                        format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_04_ExtractAction"],
                        {
                            params ["_target", "_caller", "_actionId", "_arguments"];
                            private _hvt = _arguments select 0;

                            _target removeAction _actionId;

                            [_hvt] joinSilent (group _target);
                            _hvt assignAsCargo _target;
                            [_hvt] orderGetIn true;
                        },
                        [_hvt],
                        6.0,
                        true,
                        true,
                        "",
                        "alive _target && (_target distance _this < 10) && (vehicle (missionNamespace getVariable ['LL_Task04_HVT', objNull]) != _target)"
                    ]
                ] remoteExec ["addAction", 0, _heli];
            };
        };
    };

    // --- Boucle de fin ---
    waitUntil {
        sleep 2;
        !alive _hvt || vehicle _hvt != _hvt
    };

    if (alive _hvt) then {
        ["task_04_capture", "SUCCEEDED", true] call BIS_fnc_taskSetState;
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    } else {
        ["task_04_capture", "FAILED", true] call BIS_fnc_taskSetState;
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];

        if (missionNamespace getVariable ["LL_HELI_type", ""] == "EMBARQUEMENT") then {
            missionNamespace setVariable ["LL_HELI_abort", true, false];
            ["STR_LL_Heli_Dispatch_Abort_DEFAULT"] remoteExec ["LL_fnc_radioMessage", 0];
        };
    };

    // --- Nettoyage ---
    private _allUnits = missionNamespace getVariable ["LL_Task04_AllUnits", []];
    private _guards = _allUnits select { _x != _hvt && alive _x };

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
};
