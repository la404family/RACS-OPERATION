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
        diag_log "[LL] task00 ERROR: Impossible de trouver 2 lieux à >250m. Relance dans 15s.";
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
        private _numInner = 2 + floor (random 2); // 2 or 3 units
        for "_g" from 1 to _numInner do {
            sleep 0.5;
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
        private _numOuter = 2 + floor (random 2); // 2 or 3 units
        for "_g" from 1 to _numOuter do {
            sleep 0.5;
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
            sleep 0.7;
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
                ["task_00_exfiltration", "FAILED", true] call BIS_fnc_taskSetState;
                missionNamespace setVariable ["LL_g_taskInProgress", false, true];
            }];

            [_hostage] remoteExec ["LL_fnc_task00_addAction", 0, true];
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
    _hostage setBehaviour "CARELESS";
    _hostage setSpeedMode "LIMITED";
    _hostage setSkill ["courage", 1];
    _hostage allowFleeing 0;

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
                
                // Delete active patrol waypoints and assign a Search and Destroy (SAD) waypoint targeting the nearest player
                while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                private _wp = _grp addWaypoint [getPosATL _nearest, 10];
                _wp setWaypointType "SAD";
                _wp setWaypointSpeed "FULL";
                _wp setWaypointBehaviour "COMBAT";
            };
        } forEach _allOpfor;
    };

    for "_i" from 0 to 3 do { deleteMarker format ["mkr_task00_zone_%1", _i]; };

    ["EMBARQUEMENT", getPos _hostage, _caller, 3] spawn LL_fnc_heliDispatch;

    [_hostage] spawn {
        params ["_hostage"];
        waitUntil {
            sleep 1;
            !alive _hostage || !isNull (missionNamespace getVariable ["LL_HELI_obj", objNull])
        };

        if (alive _hostage) then {
            private _heli = missionNamespace getVariable ["LL_HELI_obj", objNull];
            if (!isNull _heli) then {
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
        };
    };

    waitUntil {
        sleep 2;
        !alive _hostage || vehicle _hostage != _hostage
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
