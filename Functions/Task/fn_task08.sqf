params [["_mode", "init", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {};

if (_mode == "plant") exitWith {
    _args params ["_jammer", "_caller"];

    if ((_jammer getVariable ["LL_Task_Status", "WAIT"]) != "WAIT") exitWith {};
    _jammer setVariable ["LL_Task_Status", "ACTION", true];

    _caller playMove "AinvPknlMstpSnonWnonDnon_medic_1";

    ["STR_LL_Task_03_Warning", [], 6, false] remoteExec ["LL_fnc_radioMessage", 0];

    private _pos = getPosATL _jammer;
    private _charge = createVehicle ["DemoCharge_F", _pos, [], 0, "CAN_COLLIDE"];
    _charge setPosATL _pos;

    [_jammer, _charge] spawn {
        params ["_jammer", "_charge"];

        sleep 40;

        if (!isNull _charge) then { deleteVehicle _charge; };

        if (!isNull _jammer && alive _jammer) then {
            private _pos = getPos _jammer;
            "Bo_GBU12_LGB" createVehicle _pos;
            _jammer setDamage 1; 
        };
    };
};

if (_mode == "init") exitWith {
    private _allHeliports = [];
    {
        if ((_x select [0, 9]) == "Heliport_") then {
            private _obj = missionNamespace getVariable [_x, objNull];
            if (!isNull _obj) then { _allHeliports pushBack _obj; };
        };
    } forEach (allVariables missionNamespace);

    private _alivePlayers = allPlayers select { alive _x };
    private _logicJammer = objNull;
    private _logicVehicles = objNull;
    private _maxDist = 2000;

    while { isNull _logicJammer && _maxDist <= 15000 } do {
        private _eligibleHeliports = _allHeliports select {
            private _pos = getPosASL _x;
            private _ok = true;
            { private _d = _x distance2D _pos; if (_d < 250 || _d > _maxDist) exitWith { _ok = false; }; } forEach _alivePlayers;
            _ok
        };

        if (count _eligibleHeliports >= 2) then {
            private _shuffled = _eligibleHeliports call BIS_fnc_arrayShuffle;
            {
                private _candJammer = _x;
                private _validVeh = (_shuffled - [_candJammer]) select { (_x distance2D _candJammer) >= 600 };
                if (count _validVeh > 0) exitWith {
                    _logicJammer = _candJammer;
                    _validVeh = [_validVeh, [], { _x distance2D _candJammer }, "ASCEND"] call BIS_fnc_sortBy;
                    _logicVehicles = _validVeh select 0;
                };
            } forEach _shuffled;
        };

        if (isNull _logicJammer) then { _maxDist = _maxDist + 500; };
    };

    if (isNull _logicJammer || isNull _logicVehicles) exitWith {
        diag_log "[LL] task08 ERROR: Impossible de trouver 2 Heliport_ valides et distants de >600m. Relance dans 15s.";
        [[], "LL_fnc_task08"] spawn { sleep 15; ["init"] spawn LL_fnc_task08; };
    };

    private _posJammer = getPosASL _logicJammer;
    _posJammer set [2, (_posJammer select 2) + 0.2];

    private _posVeh = getPosASL _logicVehicles;
    _posVeh set [2, (_posVeh select 2) + 0.2];

    private _totalEnemies = 15 + floor (random 11);

    private _groupSizes = [];
    private _rem = _totalEnemies;
    for "_i" from 1 to 4 do {
        private _sz = (3 + floor(random 3)) min (_rem - (5 - _i));
        _groupSizes pushBack _sz;
        _rem = _rem - _sz;
    };
    _groupSizes pushBack _rem;

    private _enemies = [];
    private _groups = [];
    private _classes = ["CUP_O_TK_Soldier", "CUP_O_TK_Soldier_GL", "CUP_O_TK_Soldier_AR", "CUP_O_TK_Soldier_AT"];

    for "_gIdx" from 0 to 4 do {
        private _sz = _groupSizes select _gIdx;
        private _grp = createGroup [east, true];
        _grp setBehaviour "AWARE";
        _grp setCombatMode "RED";

        private _centerPos = if (_gIdx < 2) then { _posJammer } else { _posVeh };

        for "_u" from 1 to _sz do {
            sleep 1.5; 
            private _cls = selectRandom _classes;
            private _spawnSpot = _centerPos getPos [random 15, random 360];
            private _unit = _grp createUnit [_cls, _spawnSpot, [], 0, "NONE"];
            _unit setPosASL _spawnSpot;
            _unit allowDamage false;
            [_unit] spawn { sleep 3; (_this select 0) allowDamage true; };

            _unit setSkill ["courage", 1];
            _unit allowFleeing 0;

            _enemies pushBack _unit;
        };

        switch (_gIdx) do {
            case 0: { 
                { _x disableAI "MOVE"; } forEach units _grp;
            };
            case 1: { 
                [_grp, _posJammer, 20] call BIS_fnc_taskPatrol;
            };
            case 2: { 
                { _x setUnitPos "UP"; } forEach units _grp;
            };
            case 3: { 
                [_grp, _posVeh, 30] call BIS_fnc_taskPatrol;
            };
            case 4: { 
                [_grp, _posVeh, 80] call BIS_fnc_taskPatrol;
            };
        };
        _groups pushBack _grp;
    };

    sleep 1.5;

    private _jammer = createVehicle ["O_Truck_03_device_F", _posJammer, [], 0, "NONE"];
    _jammer setPosASL _posJammer;
    _jammer allowDamage false;
    [_jammer] spawn { sleep 3; (_this select 0) allowDamage true; };
    _jammer setFuel 0; 

    _jammer setVariable ["LL_Task_Status", "WAIT", true];
    [_jammer, netId _jammer] remoteExec ["LL_fnc_task08_addAction", 0, _jammer];

    private _dca = createVehicle ["O_T_APC_Tracked_02_AA_ghex_F", _posVeh, [], 0, "NONE"];
    _dca setPosASL _posVeh;
    _dca allowDamage false;
    [_dca] spawn { sleep 3; (_this select 0) allowDamage true; };
    createVehicleCrew _dca;
    (group (driver _dca)) setCombatMode "RED";
    (group (driver _dca)) setBehaviour "COMBAT";
    _dca setFuel 0; 

    private _dirVeh = getDir _logicVehicles;
    private _posGrad = _posVeh getPos [12, _dirVeh + 90];
    _posGrad set [2, (_posVeh select 2)];
    private _artillery = createVehicle ["CUP_O_BM21_SLA", _posGrad, [], 0, "NONE"];
    _artillery setPosASL _posGrad;
    _artillery setDir _dirVeh;
    _artillery allowDamage false;
    [_artillery] spawn { sleep 3; (_this select 0) allowDamage true; };
    createVehicleCrew _artillery;
    (group (driver _artillery)) setCombatMode "RED";
    (group (driver _artillery)) setBehaviour "COMBAT";
    _artillery setFuel 0; 

    missionNamespace setVariable ["LL_Task08_Targets", [_dca, _artillery, _jammer], true];
    missionNamespace setVariable ["LL_Drone_Jammed", true, true];
    missionNamespace setVariable ["LL_Heli_Jammed", true, true];
    missionNamespace setVariable ["LL_Task08_Finished", false, true];

    private _mkrJammer = "mkr_task08_jammer";
    createMarker [_mkrJammer, _posJammer];
    _mkrJammer setMarkerType "mil_objective";
    _mkrJammer setMarkerColor "ColorRed";
    _mkrJammer setMarkerText (localize "STR_LL_Task_08_Marker");

    private _mkrVehicles = "mkr_task08_vehicles";
    createMarker [_mkrVehicles, _posVeh];
    _mkrVehicles setMarkerType "mil_warning";
    _mkrVehicles setMarkerColor "ColorRed";
    _mkrVehicles setMarkerText (localize "STR_LL_Task_08_MarkerVehicles");

    [
        independent,
        ["task_08_main"],
        [
            localize "STR_LL_Task_08_Desc",
            localize "STR_LL_Task_08_Title",
            localize "STR_LL_Task_08_Marker"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "destroy",
        false
    ] call BIS_fnc_taskCreate;

    [[], { player createDiaryRecord ["diary", [localize "STR_LL_Diary_Task08_Title", localize "STR_LL_Diary_Task08_Text"]]; }] remoteExec ["spawn", 0, true];

    [_posVeh, _jammer, _dca, _mkrJammer, _mkrVehicles] spawn {
        params ["_posVeh", "_jammer", "_dca", "_mkrJammer", "_mkrVehicles"];

        private _delay = 2400 + random 900; 
        private _startTime = time;
        private _endTime = _startTime + _delay;

        while { time < _endTime && !(missionNamespace getVariable ["LL_Task08_Finished", false]) } do {
            private _timeLeft = _endTime - time;
            private _min = floor (_timeLeft / 60);
            private _sec = floor (_timeLeft % 60);

            private _timerStr = if (_min > 0) then {
                format ["%1 min %2%3s", _min, if (_sec < 10) then {"0"} else {""}, _sec]
            } else {
                format ["%1s", _sec]
            };

            if (getMarkerColor _mkrVehicles != "") then {
                private _defaultTextVeh = localize "STR_LL_Task_08_MarkerVehicles";
                _mkrVehicles setMarkerText (format ["%1 (%2)", _defaultTextVeh, _timerStr]);
            };

            if (getMarkerColor _mkrJammer != "") then {
                private _defaultTextJam = localize "STR_LL_Task_08_Marker";
                _mkrJammer setMarkerText (format ["%1 (%2)", _defaultTextJam, _timerStr]);
            };

            sleep 1;
        };

        if (getMarkerColor _mkrVehicles != "") then {
            _mkrVehicles setMarkerText (localize "STR_LL_Task_08_MarkerVehicles");
        };
        if (getMarkerColor _mkrJammer != "") then {
            _mkrJammer setMarkerText (localize "STR_LL_Task_08_Marker");
        };

        if (missionNamespace getVariable ["LL_Task08_Finished", false]) exitWith {};

        ["STR_LL_Task_08_Plane_Incoming"] remoteExec ["LL_fnc_radioMessage", 0];

        private _angleIn = random 360;
        private _dist = (worldSize / 2) max 4000;
        private _spawnPos2D = _posVeh getPos [_dist, _angleIn];
        private _targetPos2D = _posVeh getPos [_dist, _angleIn + 180];

        private _spawnPos = [_spawnPos2D select 0, _spawnPos2D select 1, 1500]; // Spawn en haute altitude (ASL) anti-montagne
        private _targetPos = [_targetPos2D select 0, _targetPos2D select 1, 300];

        private _grpPlane = createGroup [independent, true];
        private _plane = createVehicle ["CUP_I_C130J_Cargo_RACS", _spawnPos, [], 0, "FLY"];
        _plane setPosASL _spawnPos;
        _plane setDir (_spawnPos getDir _posVeh);
        _plane setVelocityModelSpace [0, 150, 0]; // Injection de vélocité (Anti-Stall)
        _plane flyInHeight 300; // Descente en douceur
        createVehicleCrew _plane;
        (crew _plane) joinSilent _grpPlane;

        private _wp1 = _grpPlane addWaypoint [_posVeh, 0];
        _wp1 setWaypointType "MOVE";
        _wp1 setWaypointSpeed "NORMAL";
        _wp1 setWaypointBehaviour "CARELESS";

        private _wp2 = _grpPlane addWaypoint [_targetPos, 0];
        _wp2 setWaypointType "MOVE";
        _wp2 setWaypointSpeed "NORMAL";

        waitUntil { sleep 3; !alive _plane || _plane distance2D _targetPos < 500 || (missionNamespace getVariable ["LL_Task08_Finished", false]) };

        if (missionNamespace getVariable ["LL_Task08_Finished", false]) exitWith {
            { deleteVehicle _x; } forEach (crew _plane);
            deleteVehicle _plane;
            deleteGroup _grpPlane;
        };

        if (!alive _plane) then {
            ["STR_LL_Task_08_Plane_ShotDown"] remoteExec ["LL_fnc_radioMessage", 0];
            ["task_08_main", "FAILED", true] call BIS_fnc_taskSetState;
            missionNamespace setVariable ["LL_Task08_Finished", true, true];
        } else {
            { deleteVehicle _x; } forEach (crew _plane);
            deleteVehicle _plane;
        };
        deleteGroup _grpPlane;
    };

    [_jammer, _dca, _artillery, _mkrJammer, _mkrVehicles, _enemies, _groups] spawn {
        params ["_jammer", "_dca", "_artillery", "_mkrJammer", "_mkrVehicles", "_enemies", "_groups"];

        private _droneUnjammed = false;
        private _heliUnjammed = false;

        while { (alive _jammer || alive _dca || alive _artillery) && !(missionNamespace getVariable ["LL_Task08_Finished", false]) } do {
            sleep 2;

            if (!_heliUnjammed && {!alive _dca}) then {
                _heliUnjammed = true;
                missionNamespace setVariable ["LL_Heli_Jammed", false, true];
                if (getMarkerColor _mkrVehicles != "") then { deleteMarker _mkrVehicles; };
                ["STR_LL_Heli_Action_Unjammed"] remoteExec ["LL_fnc_radioMessage", 0];
                sleep 5; 
            };

            if (!_droneUnjammed && {!alive _jammer}) then {
                _droneUnjammed = true;
                missionNamespace setVariable ["LL_Drone_Jammed", false, true];
                if (getMarkerColor _mkrJammer != "") then { deleteMarker _mkrJammer; };
                ["STR_LL_Drone_Action_Unjammed"] remoteExec ["LL_fnc_radioMessage", 0];

                if (alive _dca) then {
                    _dca setCaptive true;
                    { _x setCaptive true; } forEach (crew _dca);
                };
                sleep 5; 
            };
        };

        private _success = !(alive _jammer || alive _dca || alive _artillery);

        if (_success) then {

            ["task_08_main", "SUCCEEDED", true] call BIS_fnc_taskSetState;
            missionNamespace setVariable ["LL_Task08_Finished", true, true];
            
            // Avion récompense d'immersion (5 minutes plus tard)
            [_posVeh] spawn {
                params ["_posVeh"];
                sleep 300; // 5 minutes
                
                private _angleIn = random 360;
                private _dist = (worldSize / 2) max 4000;
                private _startPos = _posVeh getPos [_dist, _angleIn];
                private _endPos = _posVeh getPos [_dist, _angleIn + 180];
                
                _startPos set [2, 300];
                _endPos set [2, 300];
                
                // On réutilise le message radio confirmant que le ciel est dégagé
                ["STR_LL_Task_08_Plane_Safe"] remoteExec ["LL_fnc_radioMessage", 0];
                
                [
                    _startPos, 
                    _endPos, 
                    300, 
                    "NORMAL", 
                    "CUP_I_C130J_Cargo_RACS", 
                    independent
                ] call BIS_fnc_ambientFlyby;
            };
        } else {

            if (["task_08_main"] call BIS_fnc_taskState != "FAILED") then {
                ["task_08_main", "FAILED", true] call BIS_fnc_taskSetState;
            };

            {
                private _veh = _x;
                if (!isNull _veh && alive _veh) then {
                    private _crew = crew _veh;
                    {
                        unassignVehicle _x;
                        moveOut _x;
                    } forEach _crew;
                };
            } forEach [_jammer, _dca, _artillery];

            [_jammer, _dca, _artillery] spawn {
                params ["_jammer", "_dca", "_artillery"];
                sleep 20;
                {
                    private _veh = _x;
                    if (!isNull _veh) then {
                        private _pos = getPosATL _veh;

                        [_pos, 15, 5, [0.2, 0.2, 0.2, 0.8]] remoteExec ["LL_fnc_createSmokeRing", 0];

                        { deleteVehicle _x; } forEach (crew _veh);
                        deleteVehicle _veh;
                    };
                } forEach [_jammer, _dca, _artillery];
            };
        };

        private _allEnemies = [];
        {
            if (!isNull _x && alive _x) then {
                _allEnemies pushBack _x;
            };
        } forEach _enemies;

        {
            private _veh = _x;
            if (!isNull _veh) then {
                {
                    if (!isNull _x && alive _x && !(_x in _allEnemies)) then {
                        _allEnemies pushBack _x;
                    };
                } forEach (crew _veh);
            };
        } forEach [_jammer, _dca, _artillery];

        [_allEnemies, _groups] spawn {
            params ["_enemiesToHunt", "_originalGroups"];

            {
                if (!isNull _x) then {
                    _x setBehaviour "AWARE";
                    _x setCombatMode "RED";
                    _x setSpeedMode "FULL";
                };
            } forEach _originalGroups;

            {
                if (alive _x) then {
                    _x enableAI "MOVE";
                    _x enableAI "AUTOTARGET";
                    _x enableAI "TARGET";
                    _x enableAI "WEAPONAIM";
                    _x setUnitPos "UP";
                    _x setBehaviour "COMBAT";
                    _x setSpeedMode "FULL";
                };
            } forEach _enemiesToHunt;

            while { ({ alive _x } count _enemiesToHunt) > 0 } do {
                private _alivePlayers = allPlayers select { alive _x };
                if (count _alivePlayers == 0) exitWith {};

                {
                    private _enemy = _x;
                    if (alive _enemy) then {
                        private _closestPlayer = objNull;
                        private _minDist = 999999;
                        {
                            private _d = _enemy distance2D _x;
                            if (_d < _minDist) then {
                                _minDist = _d;
                                _closestPlayer = _x;
                            };
                        } forEach _alivePlayers;

                        if (!isNull _closestPlayer) then {
                            _enemy reveal [_closestPlayer, 4];

                            private _lastPush = _enemy getVariable ["LL_Task08_LastPush", 0];
                            if (time - _lastPush > 10) then {
                                _enemy setVariable ["LL_Task08_LastPush", time];
                                _enemy doMove (getPosATL _closestPlayer);
                            };
                        };
                    };
                } forEach _enemiesToHunt;

                sleep 5;
            };
        };

        missionNamespace setVariable ["LL_Drone_Jammed", false, true];
        missionNamespace setVariable ["LL_Heli_Jammed", false, true];

        if (getMarkerColor _mkrJammer != "") then { deleteMarker _mkrJammer; };
        if (getMarkerColor _mkrVehicles != "") then { deleteMarker _mkrVehicles; };

        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    };
};
