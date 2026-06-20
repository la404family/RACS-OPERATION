params [["_mode", "init", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {};

if (_mode == "init") exitWith {
    private _allLogics = (allMissionObjects "Logic") select { (vehicleVarName _x) select [0, 11] == "M_Dans_Bat_" };
    if (count _allLogics < 2) exitWith {
        diag_log "[LL] task02 ERROR: Pas assez de M_Dans_Bat_ sur la carte.";
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
    if (_numZones < 2) exitWith {
        diag_log "[LL] task02 ERROR: Impossible de trouver 2 lieux valides. Relance dans 15s.";
        [[], "LL_fnc_task02"] spawn { sleep 15; ["init"] spawn LL_fnc_task02; };
    };

    missionNamespace setVariable ["LL_Task02_AllUnits", [], true];
    private _allUnits = [];
    private _bombs = [];
    private _statuses = [];
    for "_i" from 0 to (_numZones - 1) do { _statuses pushBack "WAIT"; };
    missionNamespace setVariable ["LL_Task02_BombStatuses", _statuses, true];

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

        private _mkrName = format ["mkr_task02_zone_%1", _i];
        createMarker [_mkrName, _spawnPos];
        _mkrName setMarkerType "mil_objective";
        _mkrName setMarkerColor "ColorOrange";
        _mkrName setMarkerText format ["%1 %2", localize "STR_LL_Task_02_Marker", _i + 1];

        sleep 4;

        private _bomb = createVehicle ["Box_East_Grenades_F", [0,0,0], [], 0, "CAN_COLLIDE"];
        _bomb setPosASL _spawnPos;
        _bomb setDir (random 360);
        _bomb setVariable ["LL_Bomb_Status", "WAIT", true];
        _bomb setVariable ["LL_Bomb_Index", _i, true];

        _bomb allowDamage false;
        [_bomb] spawn { sleep 3; (_this select 0) allowDamage true; };

        private _charge = createVehicle ["DemoCharge_F", _spawnPos vectorAdd [0, 0, 1], [], 0, "CAN_COLLIDE"];
        _charge attachTo [_bomb, [0, 0, 0.32]]; 
        _charge setVectorUp [0, 0, 1];

        private _light = "#lightpoint" createVehicle [0,0,0];
        _light attachTo [_bomb, [0, 0, 0.31]]; 
        _light setLightColor [1, 0.2, 0]; 
        _light setLightAmbient [0, 0, 0]; 
        _light setLightUseFlare true;
        _light setLightFlareSize 0.1; 
        _light setLightFlareMaxDistance 50;
        _light setLightAttenuation [0.1, 0, 100, 100]; 
        _light setLightBrightness 0;

        _bomb addEventHandler ["Killed", {
            params ["_unit", "_killer", "_instigator", "_useEffects"];
            _unit setVariable ["LL_Bomb_Status", "EXPLODED", true];
            private _idx = _unit getVariable ["LL_Bomb_Index", -1];
            if (_idx != -1) then {
                private _statuses = missionNamespace getVariable ["LL_Task02_BombStatuses", []];
                _statuses set [_idx, "EXPLODED"];
                missionNamespace setVariable ["LL_Task02_BombStatuses", _statuses, true];
            };

            "Bo_GBU12_LGB" createVehicle (getPos _unit);
        }];

        [_bomb, _light, _charge] spawn {
            params ["_bomb", "_light", "_charge"];
            while { alive _bomb && (_bomb getVariable ["LL_Bomb_Status", "WAIT"]) == "WAIT" } do {
                playSound3D ["A3\Sounds_F\sfx\beep_target.wss", _bomb, false, getPosASL _bomb, 1, 1, 50];
                _light setLightBrightness 0.5; 
                sleep 0.1;
                _light setLightBrightness 0; 
                sleep 1.9;
            };

            if (!isNull _light) then { deleteVehicle _light; };

            if (alive _bomb && (_bomb getVariable ["LL_Bomb_Status", "WAIT"]) == "DEFUSED") then {
                if (!isNull _charge) then { deleteVehicle _charge; };
            };
        };

        _bombs pushBack _bomb;

        private _varName = format ["LL_Task02_Bomb_%1_%2", _i, round(random 100000)];
        _bomb setVehicleVarName _varName;
        missionNamespace setVariable [_varName, _bomb, true];

        [_bomb, netId _bomb, _varName] remoteExec ["LL_fnc_task02_addAction", 0, _bomb];
    };

    missionNamespace setVariable ["LL_Task02_AllUnits", _allUnits, true];
    missionNamespace setVariable ["LL_Task02_Bombs", _bombs, true];

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

    [[], { player createDiaryRecord ["diary", [localize "STR_LL_Diary_Task02_Title", localize "STR_LL_Diary_Task02_Text"]]; }] remoteExec ["spawn", 0, true];

    ["STR_LL_Task_Assigned"] remoteExec ["LL_fnc_radioMessage", 0];

    private _timerMinutes = 25 + floor(random 21); 
    [_timerMinutes, _bombs, _numZones] spawn {
        params ["_timerMinutes", "_bombs", "_numZones"];
        private _endTime = time + (_timerMinutes * 60);
        private _taskDone = false;
        private _alertTriggered = false;

        while { !_taskDone } do {
            sleep 1; 
            private _defusedCount = 0;
            private _explodedCount = 0;
            private _statuses = missionNamespace getVariable ["LL_Task02_BombStatuses", []];

            {
                if (_x == "DEFUSED") then { _defusedCount = _defusedCount + 1; };
                if (_x == "EXPLODED") then { _explodedCount = _explodedCount + 1; };
            } forEach _statuses;

            private _remaining = round (_endTime - time);
            if (_remaining < 0) then { _remaining = 0; };
            private _mins = floor (_remaining / 60);
            private _secs = _remaining mod 60;
            private _timeStr = format ["%1:%2", if (_mins < 10) then {"0"+str _mins} else {str _mins}, if (_secs < 10) then {"0"+str _secs} else {str _secs}];

            if (!_alertTriggered && _remaining <= 420) then {
                _alertTriggered = true;
                private _alivePlayers = allPlayers select { alive _x };
                private _guards = (missionNamespace getVariable ["LL_Task02_AllUnits", []]) select { alive _x };
                if (count _guards > 0 && count _alivePlayers > 0) then {
                    private _grpsProcessed = [];
                    {
                        private _guard = _x;
                        _guard setBehaviour "COMBAT";
                        _guard setCombatMode "RED";
                        _guard setSpeedMode "FULL";
                        { _guard reveal [_x, 4]; } forEach _alivePlayers;

                        private _grp = group _guard;
                        if !(_grp in _grpsProcessed) then {
                            _grpsProcessed pushBack _grp;
                            private _grpPos = getPosATL (leader _grp);
                            private _nearest = _alivePlayers select 0;
                            private _nearestDist = _nearest distance2D _grpPos;
                            { private _d = _x distance2D _grpPos; if (_d < _nearestDist) then { _nearestDist = _d; _nearest = _x; }; } forEach _alivePlayers;

                            while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                            private _wp = _grp addWaypoint [getPosATL _nearest, 10];
                            _wp setWaypointType "SAD";
                            _wp setWaypointSpeed "FULL";
                            _wp setWaypointBehaviour "COMBAT";
                        };
                    } forEach _guards;
                };
            };

            for "_i" from 0 to (_numZones - 1) do {
                private _mkrName = format ["mkr_task02_zone_%1", _i];
                private _bombStatus = _statuses select _i;

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

            if (time > _endTime) then {
                {
                    if (!isNull _x && { (_x getVariable ["LL_Bomb_Status", "WAIT"]) == "WAIT" }) then {
                        _x setDamage 1; 
                    };
                } forEach _bombs;
                sleep 2; 
                _explodedCount = 0;
                private _currentStatuses = missionNamespace getVariable ["LL_Task02_BombStatuses", []];
                {
                    if (_x == "EXPLODED") then { _explodedCount = _explodedCount + 1; };
                } forEach _currentStatuses;
            };

            if ((_defusedCount + _explodedCount) >= _numZones) then {
                _taskDone = true;

                if (_explodedCount == _numZones) then {
                    ["task_02_bombs", "FAILED", true] call BIS_fnc_taskSetState;
                } else {
                    ["task_02_bombs", "SUCCEEDED", true] call BIS_fnc_taskSetState;
                };

                missionNamespace setVariable ["LL_g_taskInProgress", false, true];

                for "_i" from 0 to (_numZones - 1) do { deleteMarker format ["mkr_task02_zone_%1", _i]; };

                private _allUnits = missionNamespace getVariable ["LL_Task02_AllUnits", []];
                private _guards = _allUnits select { alive _x };
                [_guards] spawn LL_fnc_taskCleanup;
            };
        };
    };
};

if (_mode == "defuse") exitWith {
    _args params ["_bomb", "_caller"];

    if ((_bomb getVariable ["LL_Bomb_Status", "WAIT"]) != "WAIT") exitWith {};
    _bomb setVariable ["LL_Bomb_Status", "DEFUSED", true];

    private _idx = _bomb getVariable ["LL_Bomb_Index", -1];
    if (_idx != -1) then {
        private _statuses = missionNamespace getVariable ["LL_Task02_BombStatuses", []];
        _statuses set [_idx, "DEFUSED"];
        missionNamespace setVariable ["LL_Task02_BombStatuses", _statuses, true];
    };

    _bomb removeAllEventHandlers "Killed";
    _bomb allowDamage false;

    _caller playMove "AinvPknlMstpSnonWnonDnon_medic_1";
    [_caller, "STR_LL_Task_02_Defused"] remoteExec ["systemChat", 0];

    [_bomb] spawn {
        params ["_bomb"];
        if (isNull _bomb) exitWith {};

        private _pos = getPosATL _bomb;

        sleep 20;

        [[_pos], {
            params ["_pos"];
            [_pos] spawn {
                params ["_pos"];
                private _emitter = "#particlesource" createVehicleLocal _pos;
                _emitter setParticleCircle [0.1, [0.1, 0.1, 0]];
                _emitter setParticleRandom [2, [0.4, 0.4, 0.2], [0.5, 0.5, 0.3], 1, 0.2, [0, 0, 0, 0.05], 0, 0];
                _emitter setParticleParams [
                    ["\A3\data_f\ParticleEffects\Universal\Universal", 16, 7, 48, 1], "", "Billboard",
                    1, 8, [0, 0, 0.1], [0, 0, 0.4], 0, 1.27, 1, 0.05,
                    [1, 3.5, 6.5], 
                    [[0.9, 0.9, 0.9, 0.85], [0.95, 0.95, 0.95, 0.55], [0.95, 0.95, 0.95, 0]],
                    [0.5], 0.1, 0, "", "", _emitter
                ];
                _emitter setDropInterval 0.005; 
                sleep 2; 
                deleteVehicle _emitter;
            };
        }] remoteExec ["spawn", 0];

        sleep 1;

        if (!isNull _bomb) then {
            deleteVehicle _bomb;
        };
    };
};
