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

    private _numTrucks = 2 + floor(random 2); 
    private _selectedLogics = [];
    private _alivePlayers = allPlayers select { alive _x };
    private _logicsPool = _allLogics call BIS_fnc_arrayShuffle;
    private _maxDist = 2000;

    while { count _selectedLogics < _numTrucks && _maxDist <= 15000 } do {
        _selectedLogics = [];
        {
            private _candidate = _x;
            private _candidatePos = getPosASL _candidate;
            private _valid = true;
            { private _d = _x distance2D _candidatePos; if (_d < 750 || _d > _maxDist) exitWith { _valid = false; }; } forEach _alivePlayers;
            { if (_x distance2D _candidatePos < 250) exitWith { _valid = false; }; } forEach _selectedLogics;
            if (_valid) then { _selectedLogics pushBack _candidate; };
            if (count _selectedLogics == _numTrucks) exitWith {};
        } forEach _logicsPool;

        if (count _selectedLogics < _numTrucks) then { _maxDist = _maxDist + 500; };
    };

    if (count _selectedLogics < 1) exitWith {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then { diag_log "[LL] task04 ERROR: Impossible de trouver un Heliport_ valide. Relance dans 15s."; };
        [[], "LL_fnc_task04"] spawn { sleep 15; ["init"] spawn LL_fnc_task04; };
    };

    missionNamespace setVariable ["LL_Task04_RemainingTrucks", [], true];
    missionNamespace setVariable ["LL_Task04_AllUnits", [], true];
    missionNamespace setVariable ["LL_Task04_Failed", false, true];

    private _allTrucks = [];
    private _allUnits = [];

    {
        private _selectedLogic = _x;
        private _spawnPos = getPosASL _selectedLogic;
        _spawnPos set [2, (_spawnPos select 2) + 0.2];
        private _grpInner = createGroup [east, true];
        _grpInner setBehaviour "SAFE";
        _grpInner setCombatMode "RED";
        private _numInner = 2 + floor (random 2); 
        for "_g" from 1 to _numInner do {
            sleep 1.5;
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
            sleep 1.5;
            private _guardClass = selectRandom ["CUP_O_TK_Soldier", "CUP_O_TK_Soldier_GL", "CUP_O_TK_Soldier_AR"];
            private _guard = _grpOuter createUnit [_guardClass, _spawnPos, [], 0, "NONE"];
            _guard setPosASL _spawnPos;
            _guard allowDamage false;
            [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };
            _allUnits pushBack _guard;
        };
        [_grpOuter, _spawnPos, 60] call BIS_fnc_taskPatrol;

        sleep 1.5;
        private _truckClasses = ["CUP_O_V3S_Refuel_TKA", "CUP_O_Ural_Refuel_TKA", "CUP_I_T810_Refuel_LDF"];
        private _truck = createVehicle [selectRandom _truckClasses, _spawnPos, [], 0, "CAN_COLLIDE"];
        _truck setPosASL _spawnPos;
        _truck setDir (random 360);

        _truck setFuel 0;

        clearWeaponCargoGlobal _truck;
        clearItemCargoGlobal _truck;
        clearMagazineCargoGlobal _truck;
        clearBackpackCargoGlobal _truck;

        _allTrucks pushBack _truck;
        _allUnits pushBack _truck;

        _truck addEventHandler ["HandleDamage", {
            params ["_unit", "_selection", "_damage"];
            if (!alive _unit) exitWith { _damage };

            private _partDmg = if (_selection != "") then { _unit getHit _selection } else { damage _unit };
            if (isNil "_partDmg") then { _partDmg = damage _unit; };

            private _delta = _damage - _partDmg;
            private _newDmg = _partDmg;

            if (_delta > 0) then {
                if (_delta <= 0.05) then {
                    _delta = 0.1; 
                } else {
                    _delta = _delta * 2; 
                };
                _newDmg = _partDmg + _delta;
            };

            if (_newDmg >= 0.8) then {
                _newDmg = 1; 
            };

            private _level = (floor (_newDmg * 10)) min 9;
            if (_level >= 1) then {
                    _unit setVariable ["LL_Toxic_Level", _level max (_unit getVariable ["LL_Toxic_Level", 0]), true];
                private _emitter = _unit getVariable ["LL_Toxic_Smoke1", objNull];
                if (isNull _emitter) then {
                    _emitter = "#particlesource" createVehicle (getPos _unit);
                    _unit setVariable ["LL_Toxic_Smoke1", _emitter];

                    [_unit] spawn {
                        params ["_truck"];
                        private _startTime = time;
                        while { alive _truck && !isNull (_truck getVariable ["LL_Toxic_Smoke1", objNull]) } do {
                            private _elapsed = time - _startTime;
                            private _emitter = _truck getVariable ["LL_Toxic_Smoke1", objNull];

                            if (_elapsed >= 600) exitWith {
                                if (!isNull _emitter) then { deleteVehicle _emitter; };
                                _truck setVariable ["LL_Toxic_Smoke1", objNull];
                            };

                            private _timeFactor = (1 - (_elapsed / 600)) max 0;
                            private _lvl = _truck getVariable ["LL_Toxic_Level", 0];

                            if (_lvl >= 1 && !isNull _emitter) then {
                                private _radius = (4 + (_lvl * 0.8)) * _timeFactor;
                                private _dmg = (0.0015 * _lvl) * _timeFactor;

                                {
                                    if (alive _x && _x distance2D _truck < _radius) then {
                                        _x setDamage ((damage _x) + _dmg);
                                    };
                                } forEach allUnits;

                                private _dropInterval = (0.35 / _lvl) / (_timeFactor max 0.05);
                                _emitter setDropInterval _dropInterval;

                                private _sizeMultiplier = (1 + (_lvl * 0.15)) * _timeFactor;
                                _emitter setParticleParams [
                                     ["\A3\data_f\ParticleEffects\Universal\Universal", 16, 7, 48, 1], "", "Billboard", 1, 12,
                                     [0, 0, 0.2], [0, 0, 0.3], 0, 1.28, 1, 0.05, [1.5 * _sizeMultiplier, 3 * _sizeMultiplier, 5 * _sizeMultiplier],
                                     [[0.9, 0.85, 0.1, 0.25 * _timeFactor], [0.8, 0.75, 0.08, 0.15 * _timeFactor], [0.6, 0.55, 0.05, 0]], [0.125], 1, 0, "", "", _truck
                                ];
                                _emitter setParticleRandom [3, [2, 2, 0.2], [0.8, 0.8, 0.3], 1, 0.3, [0, 0, 0, 0.05], 0, 0];
                            };
                            sleep 1;
                        };
                    };
                };
            };

            _newDmg
        }];

        _truck setHitPointDamage ["HitEngine", 1];

        _truck addEventHandler ["Killed", {
            params ["_unit"];
            if (missionNamespace getVariable ["LL_Task04_Failed", false]) exitWith {};
            missionNamespace setVariable ["LL_Task04_Failed", true, true];

            ["task_04_convoy", "FAILED", true] call BIS_fnc_taskSetState;
            missionNamespace setVariable ["LL_g_taskInProgress", false, true];

            private _remaining = missionNamespace getVariable ["LL_Task04_RemainingTrucks", []];
            {
                private _mkr = _x getVariable ["LL_Task04_Marker", ""];
                if (_mkr != "") then { deleteMarker _mkr; };
            } forEach _remaining;

            {
                private _t = _x;
                if (!isNull _t && _t != _unit) then {
                    [_t] spawn {
                        params ["_t"];
                        waitUntil {
                            sleep 5;
                            isNull _t || !alive _t || ({ _x distance2D _t <= 800 } count (allPlayers select { alive _x })) == 0
                        };
                        if (!isNull _t) then {
                            private _emitter = _t getVariable ["LL_Toxic_Smoke1", objNull];
                            if (!isNull _emitter) then { deleteVehicle _emitter; };
                            deleteVehicle _t;
                        };
                    };
                };
            } forEach _remaining;

            private _posATL = getPosATL _unit;
            private _posASL = getPosASL _unit;

            [_posATL, 80, 8, [0.9, 0.85, 0.1, 0.8]] remoteExec ["LL_fnc_createSmokeRing", 0];

            [_posASL] spawn {
                params ["_pos"];
                private _maxRadius = 80;
                private _duration = 8;
                private _startTime = time;
                private _damagedUnits = [];

                while { (time - _startTime) < _duration } do {
                    private _progress = (time - _startTime) / _duration;
                    private _currentRadius = _maxRadius * _progress;

                    {
                        if (alive _x && !(_x in _damagedUnits)) then {
                            private _dist = _x distance _pos;
                            if (_dist <= _currentRadius) then {
                                _damagedUnits pushBack _x;
                                private _damageFactor = 1 - (_dist / _maxRadius);
                                if (_damageFactor > 0) then {

                                    private _dmg = 1.2 * _damageFactor;
                                    _x setDamage (damage _x + _dmg);

                                    if (_x isKindOf "Man") then {
                                        private _dir = _pos vectorFromTo (getPosASL _x);
                                        _dir set [2, 0.15]; 
                                        private _vel = velocity _x;
                                        _x setVelocity (_vel vectorAdd (_dir vectorMultiply (15 * _damageFactor)));
                                    };
                                };
                            };
                        };
                    } forEach (allUnits select { alive _x });

                    sleep 0.05;
                };
            };

            private _allUnits = missionNamespace getVariable ["LL_Task04_AllUnits", []];
            private _guards = _allUnits select { alive _x && _x isKindOf "Man" };
            [_guards] spawn LL_fnc_taskCleanup;
        }];

        private _idx = count _allTrucks;
        private _mkrName = format ["mkr_task04_truck_%1", _idx];
        createMarker [_mkrName, getPosASL _truck];
        _mkrName setMarkerType "mil_objective";
        _mkrName setMarkerColor "ColorOrange";
        _mkrName setMarkerText (format ["%1 (%2/%3)", localize "STR_LL_Task_04_MarkerMain", _idx, _numTrucks]);

        _truck setVariable ["LL_Task04_Marker", _mkrName, true];

        private _varName = format ["LL_Task04_Truck_%1_%2", _idx, round(random 100000)];
        _truck setVehicleVarName _varName;
        missionNamespace setVariable [_varName, _truck, true];

        [_truck, netId _truck, _varName] remoteExec ["LL_fnc_task04_addAction", 0, _truck];

    } forEach _selectedLogics;

    missionNamespace setVariable ["LL_Task04_RemainingTrucks", _allTrucks, true];
    missionNamespace setVariable ["LL_Task04_AllUnits", _allUnits, true];

    [
        independent,
        ["task_04_convoy"],
        [
            localize "STR_LL_Task_04_Desc",
            localize "STR_LL_Task_04_Title",
            ""
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
};

if (_mode == "extract") exitWith {
    _args params ["_truck", "_caller"];

    if (!alive _truck) exitWith {};

    ["STR_LL_Heli_Dispatch_Approve_EMBARQUEMENT"] remoteExec ["LL_fnc_radioMessage", 0];

    [_truck] spawn {
        params ["_cargo"];

        private _spawnPosHeli = (getPosATL _cargo) getPos [1500, random 360];
        if (_spawnPosHeli select 0 < 50 || { _spawnPosHeli select 0 > (worldSize - 50) || { _spawnPosHeli select 1 < 50 || { _spawnPosHeli select 1 > (worldSize - 50) } } }) then {
            _spawnPosHeli = [15, 15, 250];
        } else {
            _spawnPosHeli set [2, 250];
        };

        private _dropPos = _spawnPosHeli getPos [1500, random 360];
        if (_dropPos select 0 < 50 || { _dropPos select 0 > (worldSize - 50) || { _dropPos select 1 < 50 || { _dropPos select 1 > (worldSize - 50) } } }) then {
            _dropPos = [worldSize - 50, worldSize - 50, 150];
        } else {
            _dropPos set [2, 150];
        };

        private _grp = createGroup [independent, true];
        private _heli = createVehicle ["CUP_I_UH60L_FFV_RACS", _spawnPosHeli, [], 0, "FLY"];
        _heli setPosATL _spawnPosHeli;

        private _pilot = _grp createUnit ["CUP_I_RACS_Pilot", _spawnPosHeli, [], 0, "NONE"];
        _pilot moveInDriver _heli;
        private _copilot = _grp createUnit ["CUP_I_RACS_Pilot", _spawnPosHeli, [], 0, "NONE"];
        _copilot moveInTurret [_heli, [0]];

        _heli allowDamage false; 
        _grp setBehaviour "CARELESS"; 
        _grp setCombatMode "BLUE";

        { _x disableAI "FSM"; _x disableAI "TARGET"; _x disableAI "AUTOTARGET"; } forEach [_pilot, _copilot];
        _heli disableCollisionWith _cargo;
        _cargo disableCollisionWith _heli;

        while { count (waypoints _grp) > 0 } do { deleteWaypoint [_grp, 0]; };

        private _targetPos = getPos _cargo;
        private _hoverHeight = 15;
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
            (_heli distance2D _targetPos < 15) || _apTimer > 120 || !alive _heli || !alive _cargo
        };

        while { count (waypoints _grp) > 0 } do { deleteWaypoint [_grp, 0]; };

        if (!alive _heli || !alive _cargo) exitWith {};

        doStop _heli; 

        private _minH        = 9.5;
        private _heliThresh  = 10;
        private _descTimer   = 0;
        private _hoverHeight = 15;
        private _cargoASL    = (getPosASL _cargo) select 2;

        waitUntil {
            sleep 0.5; _descTimer = _descTimer + 0.5;
            private _newH = (_hoverHeight - _descTimer) max _minH;
            _heli flyInHeight _newH;

            private _targetASL = _cargoASL + _newH;
            _heli flyInHeightASL [_targetASL, _targetASL, _targetASL];

            private _heliH = getPosATL _heli select 2;
            _heliH < _heliThresh || _descTimer > 30 || !alive _heli || !alive _cargo
        };

        if (!alive _heli || !alive _cargo) exitWith {};

        _cargo allowDamage false; 
        _cargo setMass 1000; 

        sleep 0.5;
        _heli setSlingLoad _cargo;
        sleep 2;
        if (isNull (getSlingLoad _heli)) then {
            _heli setSlingLoad _cargo;
        };

        // Supprime les EH de dégâts et de mort pour éviter l'échec de la mission après treuillage (ex: largage de 150m)
        _cargo removeAllEventHandlers "Killed";
        _cargo removeAllEventHandlers "HandleDamage";

        _heli flyInHeight 50;
        private _escapeASL = _cargoASL + 50;
        _heli flyInHeightASL [_escapeASL, _escapeASL, _escapeASL];

        private _wp2 = _grp addWaypoint [_dropPos, 0];
        _wp2 setWaypointType "MOVE";
        _wp2 setWaypointSpeed "NORMAL";
        _heli doMove _dropPos;

        private _remaining = missionNamespace getVariable ["LL_Task04_RemainingTrucks", []];
        _remaining = _remaining - [_cargo];
        missionNamespace setVariable ["LL_Task04_RemainingTrucks", _remaining, true];

        private _mkr = _cargo getVariable ["LL_Task04_Marker", ""];
        if (_mkr != "") then { deleteMarker _mkr; };

        if (count _remaining == 0) then {
            ["task_04_convoy", "SUCCEEDED", true] call BIS_fnc_taskSetState;
            missionNamespace setVariable ["LL_g_taskInProgress", false, true];
        };

        waitUntil { sleep 1; _heli distance2D _dropPos < 150 };
        _heli setSlingLoad objNull;
        sleep 2;

        waitUntil {
            sleep 1;
            private _players = allPlayers select { alive _x };
            ({ _x distance2D _cargo <= 800 } count _players) == 0
        };
        deleteVehicle _cargo; 

        sleep 5;
        { deleteVehicle _x; } forEach crew _heli;
        deleteVehicle _heli;
        deleteGroup _grp;
    };
};
