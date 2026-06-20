params [["_mode", "init", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {};

if (_mode == "init") exitWith {

    private _allLogics = (allMissionObjects "Logic") select { (vehicleVarName _x) select [0, 11] == "M_Dans_Bat_" };
    if (count _allLogics < 2) exitWith {
        diag_log "[LL] task00 ERROR: Pas assez de M_Dans_Bat_ sur la carte.";
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    };

    private _targetNumZones = 2 + floor (random 3);
    private _selectedLogics = [];
    private _logicsPool = _allLogics call BIS_fnc_arrayShuffle;
    private _alivePlayers = allPlayers select { alive _x };
    private _maxDist = 2000;

    while { count _selectedLogics < 2 && _maxDist <= 15000 } do {
        _selectedLogics = [];
        {
            private _candidate = _x;
            private _candidatePos = getPosASL _candidate;
            private _valid = true;

            { private _d = _x distance2D _candidatePos; if (_d < 750 || _d > _maxDist) exitWith { _valid = false; }; } forEach _alivePlayers;

            if (_valid) then {
                { if ((getPosASL _x) distance2D _candidatePos < 250) exitWith { _valid = false; }; } forEach _selectedLogics;
            };

            if (_valid) then { _selectedLogics pushBack _candidate; };
            if (count _selectedLogics >= _targetNumZones) exitWith {};
        } forEach _logicsPool;

        if (count _selectedLogics < 2) then { _maxDist = _maxDist + 500; };
    };

    private _numZones = count _selectedLogics;
    missionNamespace setVariable ["LL_Task00_NumZones", _numZones, true];
    if (_numZones < 2) exitWith {
        diag_log "[LL] task00 ERROR: Impossible de trouver 2 lieux valides. Relance dans 15s.";
        [[], "LL_fnc_task00"] spawn { sleep 15; ["init"] spawn LL_fnc_task00; };
    };

    private _hostageIndex = floor random _numZones;
    missionNamespace setVariable ["LL_Task00_AllUnits", [], true];
    private _allUnits = [];

    for "_i" from 0 to (_numZones - 1) do {
        private _logic = _selectedLogics select _i;
        private _spawnPos = getPosASL _logic;
        _spawnPos set [2, (_spawnPos select 2) + 0.2];

        private _grpInner = createGroup [east, true];
        _grpInner setBehaviour "SAFE";
        _grpInner setCombatMode "RED";
        private _numInner = 2 + floor (random 2); 
        for "_g" from 1 to _numInner do {
            sleep 4;
            private _guardClass = selectRandom ["CUP_O_TK_Soldier", "CUP_O_TK_Soldier_GL", "CUP_O_TK_Soldier_AR"];
            private _guard = _grpInner createUnit [_guardClass, _spawnPos, [], 0, "NONE"];
            _guard setPosASL _spawnPos;
            _guard allowDamage false;
            [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };
            _allUnits pushBack _guard;
        };
        [_grpInner, _spawnPos, 20] call BIS_fnc_taskPatrol;

        private _grpOuter = createGroup [east, true];
        _grpOuter setBehaviour "SAFE";
        _grpOuter setCombatMode "RED";
        private _numOuter = 2 + floor (random 2); 
        for "_g" from 1 to _numOuter do {
            sleep 4;
            private _guardClass = selectRandom ["CUP_O_TK_Soldier", "CUP_O_TK_Soldier_GL", "CUP_O_TK_Soldier_AR"];
            private _guard = _grpOuter createUnit [_guardClass, _spawnPos, [], 0, "NONE"];
            _guard setPosASL _spawnPos;
            _guard allowDamage false;
            [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };
            _allUnits pushBack _guard;
        };
        [_grpOuter, _spawnPos, 60] call BIS_fnc_taskPatrol;

        private _mkrName = format ["mkr_task00_zone_%1", _i];
        createMarker [_mkrName, _spawnPos];
        _mkrName setMarkerType "mil_objective";
        _mkrName setMarkerColor "ColorOrange";
        _mkrName setMarkerText format ["%1 %2", localize "STR_LL_Task_00_Marker", _i + 1];

        if (_i == _hostageIndex) then {
            sleep 4;
            private _grpCiv = createGroup [civilian, true];
            private _hostage = _grpCiv createUnit ["C_man_polo_1_F", _spawnPos, [], 0, "NONE"];
            _hostage setPosASL _spawnPos;
            _hostage allowDamage false;
            [_hostage] spawn { sleep 3; (_this select 0) allowDamage true; };
            _allUnits pushBack _hostage;

            _hostage setCaptive true;
            removeAllWeapons _hostage;
            removeBackpack _hostage;

            _hostage setVariable ["LL_Task_Status", "WAIT", true];
            missionNamespace setVariable ["LL_Task00_Hostage", _hostage, true];

            _hostage disableAI "MOVE";
            _hostage disableAI "ANIM";
            _hostage setUnitPos "UP";
            _hostage switchMove "Acts_ExecutionVictim_Loop";

            _hostage addEventHandler ["AnimDone", {
                params ["_unit"];
                if (alive _unit && (_unit getVariable ["LL_Task_Status", "WAIT"]) == "WAIT") then {
                    _unit switchMove "Acts_ExecutionVictim_Loop";
                };
            }];

            _hostage addEventHandler ["Killed", {
                private _nz = missionNamespace getVariable ["LL_Task00_NumZones", 4];
                ["task_00_exfiltration", "FAILED", true] call BIS_fnc_taskSetState;
                missionNamespace setVariable ["LL_g_taskInProgress", false, true];
                for "_i" from 0 to (_nz - 1) do { deleteMarker format ["mkr_task00_zone_%1", _i]; };
            }];

            private _varName = format ["LL_Task00_Hostage_%1_%2", _i, round(random 100000)];
            _hostage setVehicleVarName _varName;
            missionNamespace setVariable [_varName, _hostage, true];

            [_hostage, netId _hostage, _varName] remoteExec ["LL_fnc_task00_addAction", 0, _hostage];
        };
    };

    missionNamespace setVariable ["LL_Task00_AllUnits", _allUnits, true];

    [
        independent,
        ["task_00_exfiltration"],
        [
            localize "STR_LL_Task_00_Desc",
            localize "STR_LL_Task_00_Title",
            localize "STR_LL_Task_00_MarkerMain"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "search",
        false
    ] call BIS_fnc_taskCreate;

    [[], { player createDiaryRecord ["diary", [localize "STR_LL_Diary_Task00_Title", localize "STR_LL_Diary_Task00_Text"]]; }] remoteExec ["spawn", 0, true];

    ["STR_LL_Task_Assigned"] remoteExec ["LL_fnc_radioMessage", 0];
};

if (_mode == "free") exitWith {
    _args params ["_hostage", "_caller"];

    if ((_hostage getVariable ["LL_Task_Status", "WAIT"]) != "WAIT") exitWith {};
    _hostage setVariable ["LL_Task_Status", "ACTION", true];

    private _hostageFixedPos = getPosASL _hostage;
    private _hostageFixedDir = getDir _hostage;

    _hostage setCaptive false;

    _hostage enableAI "ANIM";
    [_hostage, "Acts_ExecutionVictim_Unbow"] remoteExec ["switchMove", 0];

    [_hostage, _hostageFixedPos, _hostageFixedDir] spawn {
        params ["_h", "_pos", "_dir"];
        private _tStart = time;
        while { alive _h && (_h getVariable ["LL_Task_Status", "WAIT"]) == "ACTION" && (time - _tStart) < 10 } do {
            _h setPosASL _pos;
            _h setDir _dir;
            sleep 0.05;
        };
    };

    sleep 8.5;

    _hostage setPosASL _hostageFixedPos;
    _hostage setDir _hostageFixedDir;
    [_hostage, ""] remoteExec ["switchMove", 0];
    _hostage setVariable ["LL_Task_Status", "FREE", true];

    private _hostageGrp = group _hostage;
    private _dummy = _hostageGrp createUnit ["I_G_Soldier_F", getPosASL _hostage, [], 0, "NONE"];
    _dummy hideObjectGlobal true;
    _dummy allowDamage false;
    _dummy disableAI "ALL";
    _hostageGrp selectLeader _hostage;
    _dummy commandMove (getPos _hostage getPos [500, random 360]);
    sleep 3;
    deleteVehicle _dummy;

    [_hostage] joinSilent (group _caller);

    { _hostage enableAI _x; } forEach ["MOVE", "AUTOTARGET", "TARGET"];
    _hostage setUnitPos "UP";
    _hostage setSkill ["courage", 1];
    _hostage allowFleeing 0;

    _hostage disableAI "FSM";
    _hostage disableAI "AUTOCOMBAT";
    _hostage disableAI "SUPPRESSION";
    _hostage setBehaviour "CARELESS";
    _hostage setSpeedMode "FULL";

    [_hostage] spawn {
        params ["_hostage"];
        while { alive _hostage && (_hostage getVariable ["LL_Task_Status", ""]) == "FREE" && (vehicle _hostage == _hostage) } do {
            private _alivePlayers = allPlayers select { alive _x };
            if (count _alivePlayers > 0) then {
                private _closestPlayer = objNull;
                private _minDist = 999999;
                {
                    private _dist = _x distance2D _hostage;
                    if (_dist < _minDist) then {
                        _minDist = _dist;
                        _closestPlayer = _x;
                    };
                } forEach _alivePlayers;

                if (!isNull _closestPlayer && _minDist > 5) then {
                    _hostage doMove (getPosATL _closestPlayer);
                };
            };
            sleep 2;
        };
    };

    private _allBlufor = allUnits select { side _x == west && alive _x };
    private _allOpfor  = allUnits select { side _x == east && alive _x && _x != _hostage };
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

                while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                private _wp = _grp addWaypoint [getPosATL _nearest, 10];
                _wp setWaypointType "SAD";
                _wp setWaypointSpeed "FULL";
                _wp setWaypointBehaviour "COMBAT";
            };
        } forEach _allOpfor;
    };

    private _nz = missionNamespace getVariable ["LL_Task00_NumZones", 4];
    for "_i" from 0 to (_nz - 1) do { deleteMarker format ["mkr_task00_zone_%1", _i]; };

    ["EMBARQUEMENT", getPos _hostage, _caller, 3] spawn LL_fnc_heliDispatch;

    [_hostage] spawn {
        params ["_hostage"];
        while { alive _hostage && (vehicle _hostage != (missionNamespace getVariable ["LL_HELI_obj", objNull])) } do {
            private _heli = missionNamespace getVariable ["LL_HELI_obj", objNull];
            if (!isNull _heli && alive _heli && !(_heli getVariable ["LL_Task00_ActionAdded", false])) then {
                _heli setVariable ["LL_Task00_ActionAdded", true, true];
                [
                    _heli,
                    [
                        format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_00_ExtractAction"],
                        {
                            params ["_target", "_caller", "_actionId", "_arguments"];
                            private _hostage = _arguments select 0;

                            _target removeAction _actionId;

                            [_hostage] joinSilent (group _target);
                            _hostage assignAsCargo _target;
                            [_hostage] orderGetIn true;
                            _hostage moveInCargo _target;
                        },
                        [_hostage],
                        6.0,
                        true,
                        true,
                        "",
                        "alive _target && (_target distance _this < 10) && (vehicle (missionNamespace getVariable ['LL_Task00_Hostage', objNull]) != _target)"
                    ]
                ] remoteExec ["addAction", 0, _heli];
            };
            sleep 2;
        };
    };

    waitUntil {
        sleep 2;
        private _heli = missionNamespace getVariable ["LL_HELI_obj", objNull];
        !alive _hostage || (!isNull _heli && {vehicle _hostage == _heli})
    };

    if (alive _hostage) then {
        ["task_00_exfiltration", "SUCCEEDED", true] call BIS_fnc_taskSetState;
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    } else {
        ["task_00_exfiltration", "FAILED", true] call BIS_fnc_taskSetState;
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];

        if (missionNamespace getVariable ["LL_HELI_type", ""] == "EMBARQUEMENT") then {
            missionNamespace setVariable ["LL_HELI_abort", true, false];
            ["STR_LL_Heli_Dispatch_Abort_DEFAULT"] remoteExec ["LL_fnc_radioMessage", 0];
        };
    };

    private _allUnits = missionNamespace getVariable ["LL_Task00_AllUnits", []];
    private _guards = _allUnits select { _x != _hostage && alive _x };
    [_guards] spawn LL_fnc_taskCleanup;
};
