params [["_mode", "init", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {};

if (_mode == "init") exitWith {
    private _allHeliports = [];
    {
        if ((_x select [0, 9]) == "Heliport_") then {
            private _obj = missionNamespace getVariable [_x, objNull];
            if (!isNull _obj) then { _allHeliports pushBack _obj; };
        };
    } forEach (allVariables missionNamespace);
    if (count _allHeliports < 1) exitWith {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then { diag_log "[LL] task03 ERROR: Pas de Heliport_ trouvé."; };
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    };

    private _targetNumRadios = 2 + floor (random 3); 
    private _selectedRadios = [];
    private _logicsPool = _allHeliports call BIS_fnc_arrayShuffle;
    private _alivePlayers = allPlayers select { alive _x };
    private _maxDist = 2000;

    while { count _selectedRadios < 1 && _maxDist <= 15000 } do {
        _selectedRadios = [];
        {
            private _candidate = _x;
            private _candidatePos = getPosASL _candidate;
            private _valid = true;

            { private _d = _x distance2D _candidatePos; if (_d < 950 || _d > _maxDist) exitWith { _valid = false; }; } forEach _alivePlayers;

            if (_valid) then {
                { if ((getPosASL _x) distance2D _candidatePos < 250) exitWith { _valid = false; }; } forEach _selectedRadios;
            };

            if (_valid) then { _selectedRadios pushBack _candidate; };
            if (count _selectedRadios >= _targetNumRadios) exitWith {};
        } forEach _logicsPool;

        if (count _selectedRadios < 1) then { _maxDist = _maxDist + 500; };
    };

    private _numRadios = count _selectedRadios;
    if (_numRadios < 1) exitWith {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then { diag_log "[LL] task03 ERROR: Impossible de trouver des emplacements valides. Relance dans 15s."; };
        [[], "LL_fnc_task03"] spawn { sleep 15; ["init"] spawn LL_fnc_task03; };
    };

    missionNamespace setVariable ["LL_Task03_AllUnits", [], true];
    missionNamespace setVariable ["LL_Task03_Destroyed", 0, true];
    missionNamespace setVariable ["LL_Task03_Total", _numRadios, true];

    private _allUnits = [];
    private _radios = [];

    for "_i" from 0 to (_numRadios - 1) do {
        private _logic = _selectedRadios select _i;
        private _spawnPos = getPosATL _logic;

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

        private _mkrName = format ["mkr_task03_zone_%1", _i];
        createMarker [_mkrName, _spawnPos];
        _mkrName setMarkerType "mil_objective";
        _mkrName setMarkerColor "ColorOrange";
        _mkrName setMarkerText format ["%1 %2", localize "STR_LL_Task_03_Marker", _i + 1];

        sleep 4;

        private _radioClass = "RuggedTerminal_01_communications_F";
        private _radio = createVehicle [_radioClass, [0,0,0], [], 0, "CAN_COLLIDE"];
        _radio setPosATL _spawnPos;
        _radio setDir (random 360);
        _radio setVehiclePosition [_spawnPos, [], 0, "CAN_COLLIDE"];
        _radio setVectorUp (surfaceNormal _spawnPos);
        _radio setVariable ["LL_Task_Status", "WAIT", true];
        _radio setVariable ["LL_Radio_Marker", _mkrName, true];

        _radio allowDamage false;
        [_radio] spawn { sleep 3; (_this select 0) allowDamage true; };

        _radios pushBack (netId _radio);
    };

    missionNamespace setVariable ["LL_Task03_AllUnits", _allUnits, true];
    missionNamespace setVariable ["LL_Task03_Radios", _radios, true];

    [
        independent,
        ["task_03_radio"],
        [
            localize "STR_LL_Task_03_Desc",
            localize "STR_LL_Task_03_Title",
            localize "STR_LL_Task_03_MarkerMain"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "destroy",
        false
    ] call BIS_fnc_taskCreate;

    [[], { player createDiaryRecord ["diary", [localize "STR_LL_Diary_Task03_Title", localize "STR_LL_Diary_Task03_Text"]]; }] remoteExec ["spawn", 0, true];

    ["STR_LL_Task_Assigned"] remoteExec ["LL_fnc_radioMessage", 0];
};

if (_mode == "plant") exitWith {
    _args params ["_radio", "_caller"];

    if ((_radio getVariable ["LL_Task_Status", "WAIT"]) != "WAIT") exitWith {};
    _radio setVariable ["LL_Task_Status", "ACTION", true];

    _caller playMove "AinvPknlMstpSnonWnonDnon_medic_1";

    ["STR_LL_Task_03_Warning", [], 6, false] remoteExec ["LL_fnc_radioMessage", 0];

    private _pos = getPosATL _radio;
    private _charge = createVehicle ["DemoCharge_F", _pos, [], 0, "CAN_COLLIDE"];
    _charge setPosATL _pos;

    [_radio, _charge] spawn {
        params ["_radio", "_charge"];

        sleep 40; 

        if (!isNull _charge) then { deleteVehicle _charge; };

        private _pos = getPos _radio;
        private _mkrName = _radio getVariable ["LL_Radio_Marker", ""];

        "Bo_GBU12_LGB" createVehicle _pos;

        if (!isNull _radio) then { deleteVehicle _radio; };

        if (_mkrName != "") then {
            _mkrName setMarkerColor "ColorBlack";
            _mkrName setMarkerText (localize "STR_LL_Task_03_Marker_Destroyed");
        };

        private _destroyed = (missionNamespace getVariable ["LL_Task03_Destroyed", 0]) + 1;
        missionNamespace setVariable ["LL_Task03_Destroyed", _destroyed, true];
        private _total = missionNamespace getVariable ["LL_Task03_Total", 1];

        if (_destroyed >= _total) then {
            ["task_03_radio", "SUCCEEDED", true] call BIS_fnc_taskSetState;
            missionNamespace setVariable ["LL_g_taskInProgress", false, true];

            [] spawn {
                sleep 10;
                private _radios = missionNamespace getVariable ["LL_Task03_Radios", []];
                for "_i" from 0 to ((count _radios) - 1) do { deleteMarker format ["mkr_task03_zone_%1", _i]; };
            };

            private _allUnits = missionNamespace getVariable ["LL_Task03_AllUnits", []];
            private _guards = _allUnits select { alive _x };
            [_guards] spawn LL_fnc_taskCleanup;
        };
    };
};
