params [["_mode", "init", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {};

if (_mode == "init") exitWith {
    private _allLogics = (allMissionObjects "Logic") select { (vehicleVarName _x) select [0, 11] == "M_Dans_Bat_" };
    if (count _allLogics == 0) exitWith {
        diag_log "[LL] task06 ERROR: Aucun M_Dans_Bat_ trouvé sur la carte.";
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    };

    private _logicsPool = _allLogics call BIS_fnc_arrayShuffle;
    private _alivePlayers = allPlayers select { alive _x };
    private _selectedLogic = objNull;
    private _maxDist = 2000;

    while { isNull _selectedLogic && _maxDist <= 15000 } do {
        {
            private _candidate = _x;
            private _candidatePos = getPosASL _candidate;
            private _valid = true;
            { private _d = _x distance2D _candidatePos; if (_d < 250 || _d > _maxDist) exitWith { _valid = false; }; } forEach _alivePlayers;
            if (_valid) exitWith { _selectedLogic = _candidate; };
        } forEach _logicsPool;

        if (isNull _selectedLogic) then { _maxDist = _maxDist + 500; };
    };

    if (isNull _selectedLogic) exitWith {
        diag_log "[LL] task06 ERROR: Impossible de trouver un M_Dans_Bat_ valide. Relance dans 15s.";
        [[], "LL_fnc_task06"] spawn { sleep 15; ["init"] spawn LL_fnc_task06; };
    };

    missionNamespace setVariable ["LL_Task06_AllUnits", [], true];
    private _allUnits = [];

    private _spawnPos = getPosASL _selectedLogic;
    _spawnPos set [2, (_spawnPos select 2) + 0.2];

    private _grpInner = createGroup [east, true];
    _grpInner setBehaviour "SAFE";
    _grpInner setCombatMode "RED";

    private _grpOuter = createGroup [east, true];
    _grpOuter setBehaviour "SAFE";
    _grpOuter setCombatMode "RED";

    private _numGuards = 10 + floor(random 6); 
    for "_g" from 1 to _numGuards do {
        sleep 4;
        private _guardClass = selectRandom ["CUP_O_TK_Soldier", "CUP_O_TK_Soldier_GL", "CUP_O_TK_Soldier_AR"];
        private _currentGrp = if (_g % 2 == 0) then { _grpInner } else { _grpOuter };
        private _guard = _currentGrp createUnit [_guardClass, _spawnPos, [], 0, "NONE"];
        _guard setPosASL _spawnPos;
        _guard allowDamage false;
        [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };
        _allUnits pushBack _guard;
    };

    [_grpInner, _spawnPos, 30] call BIS_fnc_taskPatrol;
    [_grpOuter, _spawnPos, 90] call BIS_fnc_taskPatrol;

    sleep 4;
    private _hvtClass = "CUP_O_TK_Commander";
    private _hvt = _grpInner createUnit [_hvtClass, _spawnPos, [], 0, "NONE"];
    _hvt setPosASL _spawnPos;
    _hvt allowDamage false;
    [_hvt] spawn { sleep 3; (_this select 0) allowDamage true; };
    _allUnits pushBack _hvt;

    _hvt setCaptive true; 
    _hvt disableAI "MOVE"; 

    _hvt setVariable ["LL_Task_Status", "WAIT", true];
    missionNamespace setVariable ["LL_Task06_HVT", _hvt, true];
    missionNamespace setVariable ["LL_Task06_Triggered", false, true];

    [_hvt] spawn {
        params ["_hvt"];
        waitUntil {
            sleep 0.5;
            private _players = allPlayers select { alive _x };
            ({ _x distance2D _hvt < 5 } count _players) > 0 || !alive _hvt
        };

        if (alive _hvt) then {

            removeAllWeapons _hvt;

            _hvt enableAI "MOVE";
            _hvt enableAI "ANIM";
            _hvt disableAI "PATH";
            _hvt disableAI "FSM";
            _hvt disableAI "TARGET";
            _hvt disableAI "AUTOTARGET";
            _hvt setUnitPos "UP";
            [_hvt, "AmovPercMstpSnonWnonDnon_AmovPercMstpSsurWnonDnon"] remoteExec ["switchMove", 0];

            _hvt setVariable ["LL_Task_Status", "READY_TO_CAPTURE", true];

            private _civGrp = createGroup [civilian, true];
            [_hvt] joinSilent _civGrp;

            [_hvt, netId _hvt] remoteExec ["LL_fnc_task06_addAction", 0, _hvt];
        };
    };

    _hvt addEventHandler ["Killed", {
        params ["_unit"];
        private _parent = _unit getVariable ["LL_Task06_EscortParent", objNull];
        if (!isNull _parent && alive _parent) then {
            [_unit, _parent] remoteExec ["enableCollisionWith", 0, _unit];
            [_parent, _unit] remoteExec ["enableCollisionWith", 0, _unit];
        };
        detach _unit;

        ["task_06_hvt", "FAILED", true] call BIS_fnc_taskSetState;
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];

        if (missionNamespace getVariable ["LL_HELI_type", ""] == "EMBARQUEMENT") then {
            missionNamespace setVariable ["LL_HELI_abort", true, false];
            ["STR_LL_Heli_Dispatch_Abort_DEFAULT"] remoteExec ["LL_fnc_radioMessage", 0];
        };

        deleteMarker "mkr_task06_zone";
    }];

    private _mkrName = "mkr_task06_zone";
    createMarker [_mkrName, _spawnPos];
    _mkrName setMarkerType "mil_objective";
    _mkrName setMarkerColor "ColorOrange";
    _mkrName setMarkerText localize "STR_LL_Task_06_Marker";

    missionNamespace setVariable ["LL_Task06_AllUnits", _allUnits, true];

    [
        independent,
        ["task_06_hvt"],
        [
            localize "STR_LL_Task_06_Desc",
            localize "STR_LL_Task_06_Title",
            localize "STR_LL_Task_06_Marker"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "search",
        false
    ] call BIS_fnc_taskCreate;

    [[], { player createDiaryRecord ["diary", [localize "STR_LL_Diary_Task06_Title", localize "STR_LL_Diary_Task06_Text"]]; }] remoteExec ["spawn", 0, true];

    ["STR_LL_Task_Assigned"] remoteExec ["LL_fnc_radioMessage", 0];
};

if (_mode == "escort") exitWith {
    _args params ["_hvt", "_caller"];

    if ((_hvt getVariable ["LL_Task_Status", ""]) != "READY_TO_CAPTURE") exitWith {};
    _hvt setVariable ["LL_Task_Status", "ESCORTED", true];
    _hvt setVariable ["LL_Task06_EscortParent", _caller, true];

    _hvt enableAI "MOVE";
    _hvt enableAI "ANIM";
    _hvt enableAI "PATH";
    _hvt disableAI "FSM";
    _hvt disableAI "TARGET";
    _hvt disableAI "AUTOTARGET";
    _hvt setBehaviour "CARELESS";
    _hvt setSpeedMode "LIMITED";

    [_hvt, "AmovPercMstpSsurWnonDnon"] remoteExec ["switchMove", 0];

    [_hvt, _caller] remoteExec ["disableCollisionWith", 0];
    [_caller, _hvt] remoteExec ["disableCollisionWith", 0];

    [_hvt, _caller] spawn {
        params ["_hvt", "_caller"];
        if (isNull _hvt || isNull _caller) exitWith {};

        private _lastAnimState = "STOP";
        private _lastMoveTime = 0;

        while { alive _hvt && (_hvt getVariable ["LL_Task_Status", ""]) == "ESCORTED" } do {
            if (isNull _caller || !alive _caller) exitWith {
                _hvt setVariable ["LL_Task_Status", "READY_TO_CAPTURE", true];
                _hvt setVariable ["LL_Task06_EscortParent", objNull, true];
                _hvt disableAI "PATH";
                [_hvt, "AmovPercMstpSnonWnonDnon_AmovPercMstpSsurWnonDnon"] remoteExec ["switchMove", 0];
            };

            if (vehicle _hvt == _hvt && attachedTo _hvt isEqualTo objNull) then {
                private _targetPos = getPosATL _caller;
                private _dist = _hvt distance2D _caller;

                // Gestion dynamique de l'allure de l'otage en fonction de la distance (suivi ultra-serré)
                if (_dist > 5) then {
                    _hvt forceWalk false;
                    _hvt setSpeedMode "FULL"; // Trot/Course rapide si retard
                } else {
                    _hvt forceWalk true;
                    _hvt setSpeedMode "LIMITED"; // Marche forcée si très proche
                };

                private _playerMoving = (vectorMagnitude (velocity _caller)) > 0.2;

                if (_playerMoving || _dist > 1.8) then {
                    // Eviter de surcharger le pathfinding en limitant l'envoi de doMove à toutes les 0.4s
                    if (time - _lastMoveTime > 0.4) then {
                        _hvt doMove _targetPos;
                        _lastMoveTime = time;
                    };
                    
                    if (_lastAnimState != "MOVE") then {
                        _lastAnimState = "MOVE";
                        [_hvt, "AmovPercMstpSsurWnonDnon_AmovPercMstpSnonWnonDnon"] remoteExec ["switchMove", 0];
                    };
                } else {
                    if (_lastAnimState != "STOP") then {
                        _lastAnimState = "STOP";
                        doStop _hvt;
                        _hvt setDir (getDir _caller);
                        [_hvt, "AmovPercMstpSnonWnonDnon_AmovPercMstpSsurWnonDnon"] remoteExec ["switchMove", 0];
                    };
                };
            };
            sleep 0.15; // Boucle très rapide pour une réactivité optimale sous les 3 mètres
        };

        if (!isNull _caller) then {
            [_hvt, _caller] remoteExec ["enableCollisionWith", 0];
            [_caller, _hvt] remoteExec ["enableCollisionWith", 0];
        };

        if (alive _hvt && (_hvt getVariable ["LL_Task_Status", ""]) != "DONE") then {
            [_hvt, "AmovPercMstpSnonWnonDnon_AmovPercMstpSsurWnonDnon"] remoteExec ["switchMove", 0];
        };
    };

    if !(missionNamespace getVariable ["LL_Task06_Triggered", false]) then {
        missionNamespace setVariable ["LL_Task06_Triggered", true, true];

        private _hvtGrp = group _hvt;
        private _dummy = _hvtGrp createUnit ["I_G_Soldier_F", getPosASL _hvt, [], 0, "NONE"];
        _dummy hideObjectGlobal true;
        _dummy allowDamage false;
        _dummy disableAI "ALL";
        _hvtGrp selectLeader _hvt;
        _dummy commandMove (getPos _hvt getPos [500, random 360]);
        [_dummy] spawn { sleep 3; deleteVehicle (_this select 0); };

        ["EMBARQUEMENT", getPos _hvt, _caller, 3] spawn LL_fnc_heliDispatch;

        deleteMarker "mkr_task06_zone";

        private _allUnits = missionNamespace getVariable ["LL_Task06_AllUnits", []];
        private _guards = _allUnits select { _x != _hvt && alive _x };
        if (count _guards > 0) then {
            private _players = allPlayers select { alive _x };
            private _groups = [];
            {
                private _guard = _x;
                _guard enableAI "MOVE";
                _guard enableAI "AUTOTARGET";
                _guard enableAI "TARGET";
                _guard setBehaviour "COMBAT";
                _guard setCombatMode "RED";
                _guard setSpeedMode "FULL";
                _guard disableAI "SUPPRESSION";
                _guard setSkill ["courage", 1.0];
                _guard setSkill ["aimingAccuracy", 0.15 + random 0.10];
                { _guard reveal [_x, 4]; } forEach _players;

                private _g = group _guard;
                if !(_g in _groups) then { _groups pushBack _g; };
            } forEach _guards;

            {
                private _grp = _x;
                while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                private _wp = _grp addWaypoint [getPosATL _caller, 15];
                _wp setWaypointType "SAD";
                _wp setWaypointSpeed "FULL";
                _wp setWaypointBehaviour "COMBAT";
                _wp setWaypointCombatMode "RED";
            } forEach _groups;
        };

        [_hvt] spawn {
            params ["_hvt"];
            while { alive _hvt && ((_hvt getVariable ["LL_Task_Status", ""]) != "DONE") } do {
                private _heli = missionNamespace getVariable ["LL_HELI_obj", objNull];
                if (!isNull _heli && alive _heli && !(_heli getVariable ["LL_Task06_ActionAdded", false])) then {
                    _heli setVariable ["LL_Task06_ActionAdded", true, true];
                    [
                        _heli,
                        [
                            format ["<t color='#FFFF00'>%1</t>", if (localize "STR_LL_Task_06_ExtractAction" == "" || localize "STR_LL_Task_06_ExtractAction" == "STR_LL_Task_06_ExtractAction") then { "Embarquer le HVT" } else { localize "STR_LL_Task_06_ExtractAction" }],
                            {
                                params ["_target", "_caller", "_actionId", "_arguments"];
                                private _hvt = _arguments select 0;

                                _target removeAction _actionId;

                                _hvt setVariable ["LL_Task_Status", "DONE", true];

                                private _parent = _hvt getVariable ["LL_Task06_EscortParent", objNull];
                                if (!isNull _parent) then {
                                    [_hvt, _parent] remoteExec ["enableCollisionWith", 0, _hvt];
                                    [_parent, _hvt] remoteExec ["enableCollisionWith", 0, _hvt];
                                };
                                detach _hvt;

                                [_hvt] joinSilent (group _target);
                                _hvt assignAsCargo _target;
                                _hvt enableAI "PATH";
                                [_hvt] orderGetIn true;
                                _hvt moveInCargo _target;
                            },
                            [_hvt],
                            6.0,
                            true,
                            true,
                            "",
                            "alive _target && (_target distance _this < 10) && ((missionNamespace getVariable ['LL_Task06_HVT', objNull]) getVariable ['LL_Task_Status', '']) == 'ESCORTED' && ((missionNamespace getVariable ['LL_Task06_HVT', objNull]) getVariable ['LL_Task06_EscortParent', objNull]) == _this"
                        ]
                    ] remoteExec ["addAction", 0, _heli];
                };
                sleep 2;
            };
        };

        [_hvt] spawn {
            params ["_hvt"];
            waitUntil {
                sleep 2;
                !alive _hvt || vehicle _hvt != _hvt
            };

            if (alive _hvt) then {
                _hvt setVariable ["LL_Task_Status", "DONE", true];
                ["task_06_hvt", "SUCCEEDED", true] call BIS_fnc_taskSetState;
                missionNamespace setVariable ["LL_g_taskInProgress", false, true];
            } else {
                ["task_06_hvt", "FAILED", true] call BIS_fnc_taskSetState;
                missionNamespace setVariable ["LL_g_taskInProgress", false, true];
            };

            private _allUnits = missionNamespace getVariable ["LL_Task06_AllUnits", []];
            private _guards = _allUnits select { _x != _hvt && alive _x };

            if (count _guards > 0) then {
                private _players = allPlayers select { alive _x };
                private _groups = [];
                {
                    private _guard = _x;
                    _guard enableAI "MOVE";
                    _guard enableAI "AUTOTARGET";
                    _guard enableAI "TARGET";
                    _guard setBehaviour "COMBAT";
                    _guard setCombatMode "RED";
                    _guard setSpeedMode "FULL";
                    _guard disableAI "SUPPRESSION";
                    _guard setSkill ["courage", 1.0];
                    _guard setSkill ["aimingAccuracy", 0.15 + random 0.10];
                    { _guard reveal [_x, 4]; } forEach _players;

                    private _g = group _guard;
                    if !(_g in _groups) then { _groups pushBack _g; };
                } forEach _guards;

                if (count _players > 0) then {
                    private _firstPlayer = _players select 0;
                    {
                        private _grp = _x;
                        while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                        private _wp = _grp addWaypoint [getPosATL _firstPlayer, 15];
                        _wp setWaypointType "SAD";
                        _wp setWaypointSpeed "FULL";
                        _wp setWaypointBehaviour "COMBAT";
                        _wp setWaypointCombatMode "RED";
                    } forEach _groups;
                };
            };
        };
    };

};

if (_mode == "release") exitWith {
    _args params ["_hvt", "_caller"];

    if ((_hvt getVariable ["LL_Task_Status", ""]) != "ESCORTED") exitWith {};
    _hvt setVariable ["LL_Task_Status", "READY_TO_CAPTURE", true];
    _hvt setVariable ["LL_Task06_EscortParent", objNull, true];

    _hvt disableAI "PATH";
};
