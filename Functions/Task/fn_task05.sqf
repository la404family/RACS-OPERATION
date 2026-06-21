params [["_mode", "init", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {};

if (_mode == "init") exitWith {
    private _allLogics = (allMissionObjects "Logic") select { (vehicleVarName _x) select [0, 11] == "M_Dans_Bat_" };
    if (count _allLogics < 1) exitWith {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then { diag_log "[LL] task05 ERROR: Pas de M_Dans_Bat_ trouvé."; };
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    };

    private _targetNumChiefs = 2 + floor (random 3); 
    private _selectedLogics = [];
    private _logicsPool = _allLogics call BIS_fnc_arrayShuffle;
    private _alivePlayers = allPlayers select { alive _x };
    private _minDistPlayers = 750;
    while { count _selectedLogics < 1 && _minDistPlayers >= 100 } do {
        _maxDist = 2000;
        while { count _selectedLogics < 1 && _maxDist <= 15000 } do {
            _selectedLogics = [];
            {
                private _candidate = _x;
                private _candidatePos = getPosASL _candidate;
                private _valid = true;

                { private _d = _x distance2D _candidatePos; if (_d < _minDistPlayers || _d > _maxDist) exitWith { _valid = false; }; } forEach _alivePlayers;

                if (_valid) then {
                    { if ((getPosASL _x) distance2D _candidatePos < 250) exitWith { _valid = false; }; } forEach _selectedLogics;
                };

                if (_valid) then { _selectedLogics pushBack _candidate; };
                if (count _selectedLogics >= _targetNumChiefs) exitWith {};
            } forEach _logicsPool;

            if (count _selectedLogics < 1) then { _maxDist = _maxDist + 500; };
        };
        if (count _selectedLogics < 1) then {
            _minDistPlayers = _minDistPlayers - 50;
        };
    };

    private _numChiefs = count _selectedLogics;
    if (_numChiefs < 1) exitWith {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then { diag_log "[LL] task05 ERROR: Impossible de trouver des emplacements valides. Relance dans 15s."; };
        [[], "LL_fnc_task05"] spawn { sleep 15; ["init"] spawn LL_fnc_task05; };
    };

    missionNamespace setVariable ["LL_Task05_AllUnits", [], true];
    missionNamespace setVariable ["LL_Task05_Killed", 0, true];
    missionNamespace setVariable ["LL_Task05_Total", _numChiefs, true];
    missionNamespace setVariable ["LL_Task05_AlertTriggered", false, true];

    private _allUnits = [];
    private _chiefsData = [];

    for "_i" from 0 to (_numChiefs - 1) do {
        private _logic = _selectedLogics select _i;
        private _spawnPos = getPosASL _logic;
        _spawnPos set [2, (_spawnPos select 2) + 0.2];

        private _grp = createGroup [east, true];
        _grp setBehaviour "SAFE";

        private _numGuards = 3 + floor (random 3); 
        for "_g" from 1 to _numGuards do {
            sleep 4;
            private _guardClass = selectRandom ["CUP_O_TK_Soldier", "CUP_O_TK_Soldier_GL", "CUP_O_TK_Soldier_AR"];
            private _guard = _grp createUnit [_guardClass, _spawnPos, [], 0, "NONE"];
            _guard setPosASL _spawnPos;
            _guard allowDamage false;
            [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };
            _allUnits pushBack _guard;
        };

        sleep 4;
        private _chiefClass = selectRandom ["CUP_O_TK_Commander", "CUP_O_TK_Officer"];
        private _chief = _grp createUnit [_chiefClass, _spawnPos, [], 0, "NONE"];
        _chief setPosASL _spawnPos;
        _chief allowDamage false;
        [_chief] spawn { sleep 3; (_this select 0) allowDamage true; };
        _allUnits pushBack _chief;

        _grp selectLeader _chief;

        private _mkrName = format ["mkr_task05_chief_%1", _i];
        createMarker [_mkrName, _spawnPos];
        _mkrName setMarkerType "mil_objective";
        _mkrName setMarkerColor "ColorOrange";
        _mkrName setMarkerText format ["%1", localize "STR_LL_Task_05_Marker"];

        _chiefsData pushBack [_chief, _grp, _mkrName];

        _chief addEventHandler ["Killed", {
            params ["_unit", "_killer"];

            private _mkr = _unit getVariable ["LL_Task05_Marker", ""];
            if (_mkr != "") then {
                _mkr setMarkerColor "ColorBlack";
                _mkr setMarkerType "hd_destroy";
                _mkr setMarkerText localize "STR_LL_Task_05_Marker_Dead";
            };

            private _killed = (missionNamespace getVariable ["LL_Task05_Killed", 0]) + 1;
            missionNamespace setVariable ["LL_Task05_Killed", _killed, true];

            private _total = missionNamespace getVariable ["LL_Task05_Total", 1];

            if (_killed == 1 && _total > 1) then {
                missionNamespace setVariable ["LL_Task05_AlertTriggered", true, true];
            };

            if (_killed >= _total) then {
                ["task_05_hunt", "SUCCEEDED", true] call BIS_fnc_taskSetState;
                missionNamespace setVariable ["LL_g_taskInProgress", false, true];

                [] spawn {
                    sleep 10;

                    private _cTotal = missionNamespace getVariable ["LL_Task05_Total", 0];
                    for "_m" from 0 to (_cTotal - 1) do { deleteMarker format ["mkr_task05_chief_%1", _m]; };

                    private _allU = missionNamespace getVariable ["LL_Task05_AllUnits", []];
                    private _guards = _allU select { alive _x };
                    [_guards] spawn LL_fnc_taskCleanup;
                };
            };
        }];

        _chief setVariable ["LL_Task05_Marker", _mkrName, true];
    };

    missionNamespace setVariable ["LL_Task05_AllUnits", _allUnits, true];

    [
        independent,
        ["task_05_hunt"],
        [
            localize "STR_LL_Task_05_Desc",
            localize "STR_LL_Task_05_Title",
            localize "STR_LL_Task_05_MarkerMain"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "kill",
        false
    ] call BIS_fnc_taskCreate;

    [[], { player createDiaryRecord ["diary", [localize "STR_LL_Diary_Task05_Title", localize "STR_LL_Diary_Task05_Text"]]; }] remoteExec ["spawn", 0, true];

    ["STR_LL_Task_Assigned"] remoteExec ["LL_fnc_radioMessage", 0];

    [_chiefsData, _allLogics] spawn {
        params ["_chiefsData", "_logicsPool"];

        private _alertSent = false;

        while { missionNamespace getVariable ["LL_g_taskInProgress", false] } do {
            private _isAlerted = missionNamespace getVariable ["LL_Task05_AlertTriggered", false];

            if (_isAlerted && !_alertSent) then {
                _alertSent = true;

                ["STR_LL_Task_05_Alert"] remoteExec ["LL_fnc_radioMessage", 0];
            };

            {
                _x params ["_chief", "_grp", "_mkr"];
                if (alive _chief) then {

                    _mkr setMarkerPos (getPos _chief);

                    if (_isAlerted) then {

                        _mkr setMarkerColor "ColorRed";
                        _grp setBehaviour "COMBAT";
                        _grp setSpeedMode "FULL";

                        private _players = allPlayers select { alive _x };
                        if (count _players > 0) then {
                            private _nearest = objNull;
                            private _minDist = 999999;
                            {
                                private _d = _x distance2D _chief;
                                if (_d < _minDist) then {
                                    _minDist = _d;
                                    _nearest = _x;
                                };
                            } forEach _players;

                            if (!isNull _nearest) then {
                                while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                                private _wp = _grp addWaypoint [getPos _nearest, 0];
                                _wp setWaypointType "SAD";
                            };
                        };
                    } else {

                        if (unitReady _chief || count waypoints _grp == 0) then {
                            private _nextLogic = selectRandom _logicsPool;
                            while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                            private _wp = _grp addWaypoint [getPosASL _nextLogic, 0];
                            _wp setWaypointType "MOVE";
                            _grp setBehaviour "SAFE";
                            _grp setSpeedMode "LIMITED";
                        };
                    };
                };
            } forEach _chiefsData;

            if (_isAlerted) then { sleep 10; } else { sleep 5; };
        };
    };
};
