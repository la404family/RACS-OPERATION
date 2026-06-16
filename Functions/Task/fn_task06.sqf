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

    {
        private _candidate = _x;
        private _candidatePos = getPosASL _candidate;
        private _valid = true;
        { if (_x distance2D _candidatePos < 250) exitWith { _valid = false; }; } forEach _alivePlayers;
        if (_valid) exitWith { _selectedLogic = _candidate; };
    } forEach _logicsPool;

    if (isNull _selectedLogic) exitWith {
        diag_log "[LL] task06 ERROR: Impossible de trouver un M_Dans_Bat_ à >250m. Relance dans 15s.";
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

            _hvt disableAI "MOVE";
            _hvt enableAI "ANIM";
            _hvt setUnitPos "UP";
            [_hvt, "AmovPercMstpSsurWnonDnon"] remoteExec ["playMoveNow", 0];

            _hvt setVariable ["LL_Task_Status", "READY_TO_CAPTURE", true];

            private _civGrp = createGroup [civilian, true];
            [_hvt] joinSilent _civGrp;

            ["[SERVER] HVT s'est rendu. Envoi de l'action de capture aux clients..."] remoteExec ["systemChat", 0];

            [_hvt, netId _hvt] remoteExec ["LL_fnc_task06_addAction", 0, _hvt];
        };
    };

    _hvt addEventHandler ["Killed", {
        params ["_unit"];
        private _parent = attachedTo _unit;
        if (!isNull _parent && alive _parent) then {
            [_parent, false] remoteExec ["forceWalk", _parent];
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

    _hvt disableAI "MOVE";
    _hvt disableAI "FSM";
    _hvt attachTo [_caller, [0.5, 0.4, 0]]; 
    [_hvt, 0] remoteExec ["setDir", 0, _hvt];

    [_hvt, _caller] remoteExec ["disableCollisionWith", 0, _hvt];
    [_caller, _hvt] remoteExec ["disableCollisionWith", 0, _hvt];

    [_caller, true] remoteExec ["forceWalk", _caller];

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
                            format ["<t color='#FFFF00'>%1</t>", if (localize "STR_LL_Task_06_ExtractAction" == "" || localize "STR_LL_Task_06_ExtractAction" == "STR_LL_Task_06_ExtractAction") then { "Embarquer le HVT" } else { localize "STR_LL_Task_06_ExtractAction" }],
                            {
                                params ["_target", "_caller", "_actionId", "_arguments"];
                                private _hvt = _arguments select 0;

                                _target removeAction _actionId;

                                _hvt setVariable ["LL_Task_Status", "DONE", true];

                                private _parent = attachedTo _hvt;
                                if (!isNull _parent) then {
                                    [_parent, false] remoteExec ["forceWalk", _parent];
                                    [_hvt, _parent] remoteExec ["enableCollisionWith", 0, _hvt];
                                    [_parent, _hvt] remoteExec ["enableCollisionWith", 0, _hvt];
                                };
                                detach _hvt;

                                [_hvt] joinSilent (group _target);
                                _hvt assignAsCargo _target;
                                [_hvt] orderGetIn true;
                                _hvt moveInCargo _target;
                            },
                            [_hvt],
                            6.0,
                            true,
                            true,
                            "",
                            "alive _target && (_target distance _this < 10) && ((missionNamespace getVariable ['LL_Task06_HVT', objNull]) getVariable ['LL_Task_Status', '']) == 'ESCORTED' && attachedTo (missionNamespace getVariable ['LL_Task06_HVT', objNull]) == _this"
                        ]
                    ] remoteExec ["addAction", 0, _heli];
                };
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

    if !(_hvt getVariable ["LL_Task06_LoopRunning", false]) then {
        _hvt setVariable ["LL_Task06_LoopRunning", true, true];
        [_hvt] spawn {
            params ["_hvt"];
            while { alive _hvt && (_hvt getVariable ["LL_Task_Status", ""]) != "DONE" } do {
                private _status = _hvt getVariable ["LL_Task_Status", ""];
                if (_status == "ESCORTED") then {
                    private _parent = attachedTo _hvt;
                    if (!isNull _parent && alive _parent) then {
                        private _parentSpeed = vectorMagnitude (velocity _parent);
                        private _isMoving = _parentSpeed > 0.2;
                        private _anim = animationState _hvt;
                        if (_isMoving) then {
                            if (_anim != "amovpercmwlkssurwnondnon" && _anim != "amovpercmwlkssurwnondnon_f") then {
                                [_hvt, "AmovPercMwlkSsurWnonDnon"] remoteExec ["playMoveNow", 0];
                            };
                        } else {
                            if (_anim != "amovpercmstpssurwnondnon") then {
                                [_hvt, "AmovPercMstpSsurWnonDnon"] remoteExec ["playMoveNow", 0];
                            };
                        };
                    } else {

                        detach _hvt;
                        _hvt setVariable ["LL_Task_Status", "READY_TO_CAPTURE", true];
                        [_hvt, "AmovPercMstpSsurWnonDnon"] remoteExec ["playMoveNow", 0];
                    };
                };
                sleep 0.4;
            };
            _hvt setVariable ["LL_Task06_LoopRunning", false, true];
        };
    };
};

if (_mode == "release") exitWith {
    _args params ["_hvt", "_caller"];

    if ((_hvt getVariable ["LL_Task_Status", ""]) != "ESCORTED") exitWith {};
    _hvt setVariable ["LL_Task_Status", "READY_TO_CAPTURE", true];

    detach _hvt;

    [_hvt, _caller] remoteExec ["enableCollisionWith", 0, _hvt];
    [_caller, _hvt] remoteExec ["enableCollisionWith", 0, _hvt];

    [_caller, false] remoteExec ["forceWalk", _caller];

    [_hvt, "AmovPercMstpSsurWnonDnon"] remoteExec ["playMoveNow", 0];
};
