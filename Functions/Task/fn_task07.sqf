params [["_mode", "init", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {};

if (_mode == "init") exitWith {
    private _allLogics = (allMissionObjects "Logic") select { (vehicleVarName _x) select [0, 11] == "M_Dans_Bat_" };
    if (count _allLogics < 2) exitWith {
        diag_log "[LL] task07 ERROR: Pas assez de M_Dans_Bat_ sur la carte.";
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    };

    private _alivePlayers = allPlayers select { alive _x };
    private _eligibleLogics = _allLogics select {
        private _pos = getPosASL _x;
        private _farFromPlayers = true;
        { if (_x distance2D _pos < 250) exitWith { _farFromPlayers = false; }; } forEach _alivePlayers;
        _farFromPlayers
    };

    private _logicRdv = objNull;
    private _logicMilitia = objNull;

    if (count _eligibleLogics >= 2) then {
        private _shuffledEligible = _eligibleLogics call BIS_fnc_arrayShuffle;
        {
            private _rdvCandidate = _x;
            private _validCandidates = (_shuffledEligible - [_rdvCandidate]) select { (_x distance2D _rdvCandidate) >= 250 };
            if (count _validCandidates > 0) exitWith {
                _logicRdv = _rdvCandidate;
                _validCandidates = [_validCandidates, [], { _x distance2D _rdvCandidate }, "ASCEND"] call BIS_fnc_sortBy;
                _logicMilitia = _validCandidates select 0;
            };
        } forEach _shuffledEligible;
    };

    if (isNull _logicRdv || isNull _logicMilitia) exitWith {
        diag_log "[LL] task07 ERROR: Impossible de trouver 2 lieux valides à >250m. Relance dans 15s.";
        [[], "LL_fnc_task07"] spawn { sleep 15; ["init"] spawn LL_fnc_task07; };
    };

    private _rdvPos = getPosASL _logicRdv;
    _rdvPos set [2, (_rdvPos select 2) + 0.2];

    private _militiaPos = getPosASL _logicMilitia;
    _militiaPos set [2, (_militiaPos select 2) + 0.2];

    private _villagerGrp = createGroup [west, true];
    _villagerGrp setBehaviour "SAFE";
    _villagerGrp setCombatMode "GREEN";

    private _numVillagers = 5 + floor (random 4); // 5 to 8 villagers
    private _villagers = [];
    private _chief = objNull;

    for "_g" from 1 to _numVillagers do {
        sleep 1.5; // Staged delay

        private _class = "C_man_1";
        private _unit = _villagerGrp createUnit [_class, _rdvPos, [], 0, "NONE"];
        _unit setPosASL _rdvPos;
        _unit allowDamage false;
        [_unit] spawn { sleep 3; (_this select 0) allowDamage true; };

        // Disable automatic general template
        _unit setVariable ["MISSION_TemplateApplied", true, true];

        // Apply civilian templates loadout manually
        private _maleTemplates = MISSION_CivilianTemplates select { !(_x select 2) };
        private _template = selectRandom _maleTemplates;
        _template params ["_tClass", "_tLoadout", "_tIsFemale", "_tFace", "_tPitch"];

        _unit setUnitLoadout _tLoadout;

        // Equip as armed civilian
        removeBackpack _unit;
        _unit addBackpack (selectRandom MISSION_BanditBackpacks);

        private _bLoadout = selectRandom MISSION_BanditLoadouts;
        _bLoadout params ["_priWep","_priMag","_priMagCount","_secWep","_secMag","_secMagCount","_smoke","_smokeCount","_FAK","_FAKCount"];

        if (_priWep != "") then {
            _unit addWeapon _priWep;
            for "_i" from 1 to _priMagCount do { _unit addMagazine _priMag };
            _unit addPrimaryWeaponItem (selectRandom ["CUP_acc_Flashlight","CUP_acc_Zenit_2DS"]);
        };
        if (_secWep != "") then {
            _unit addWeapon _secWep;
            for "_i" from 1 to _secMagCount do { _unit addMagazine _secMag };
            _unit addHandgunItem (selectRandom ["CUP_acc_CZ_M3X","acc_Flashlight_pistol"]);
        };
        for "_i" from 1 to _smokeCount do { _unit addMagazine _smoke };
        for "_i" from 1 to _FAKCount do { _unit addItem _FAK };
        _unit enableGunLights "forceOn";

        // Override Hat with White Keffieh (H_ShemagOpen_khk)
        removeGoggles _unit;
        _unit addGoggles (selectRandom MISSION_CivilianBeards);
        removeHeadgear _unit;
        _unit addHeadgear "H_ShemagOpen_khk"; // White Keffieh

        // Apply name and voice identity
        private _nameData = selectRandom MISSION_CivilianNames_Male;
        private _speaker = selectRandom ["Male01PER","Male02PER","Male03PER"];
        [_unit, _nameData, _tFace, _speaker, _tPitch] remoteExec ["LL_fnc_applyIdentity", 0, _unit];
        if (!isNil "LL_fnc_setupUVO") then { [_unit] call LL_fnc_setupUVO; };

        _villagers pushBack _unit;

        if (_g == 1) then {
            _chief = _unit;
            _villagerGrp selectLeader _chief;

            // Wait animation loop for chief
            _chief disableAI "MOVE";
            _chief setUnitPos "UP";
            _chief switchMove "Acts_CivilTalking_1";

            _chief addEventHandler ["AnimDone", {
                params ["_unit"];
                if (alive _unit && (_unit getVariable ["LL_Task_Status", "WAIT"]) == "WAIT") then {
                    _unit switchMove "Acts_CivilTalking_1";
                };
            }];

            // Chief faces closest player
            [_chief] spawn {
                params ["_unit"];
                while { alive _unit && (_unit getVariable ["LL_Task_Status", "WAIT"]) == "WAIT" } do {
                    private _nearPlayers = _unit nearEntities ["CAManBase", 100] select { isPlayer _x && alive _x };
                    if (count _nearPlayers > 0) then {
                        private _nearest = _nearPlayers # 0;
                        _unit setDir (_unit getDir _nearest);
                        _unit setFormDir (_unit getDir _nearest);
                    };
                    sleep 2;
                };
            };
        } else {
            // Villagers patrol slightly around rendezvous point
            [_unit] spawn {
                params ["_unit"];
                _unit setBehaviour "SAFE";
                _unit setSpeedMode "LIMITED";
                private _pos = getPosATL _unit;
                while { alive _unit && !(_unit getVariable ["LL_Task07_RunningToBattle", false]) } do {
                    sleep (5 + random 10);
                    if (alive _unit && !(_unit getVariable ["LL_Task07_RunningToBattle", false])) then {
                        private _dest = _pos getPos [10 + random 15, random 360];
                        _unit doMove _dest;
                    };
                };
            };
        };
    };

    _chief setVariable ["LL_Task_Status", "WAIT", true];
    missionNamespace setVariable ["LL_Task07_Chief", _chief, true];
    missionNamespace setVariable ["LL_Task07_Villagers", _villagers, true];
    missionNamespace setVariable ["LL_Task07_VillagerGroup", _villagerGrp, true];
    missionNamespace setVariable ["LL_Task07_MilitiaPos", _militiaPos, true];

    private _mkrRdv = "mkr_task07_rdv";
    createMarker [_mkrRdv, _rdvPos];
    _mkrRdv setMarkerType "mil_objective";
    _mkrRdv setMarkerColor "ColorGreen";
    _mkrRdv setMarkerText (localize "STR_LL_Task_07_RDV_Marker");

    [
        independent,
        ["task_07_rdv"],
        [
            localize "STR_LL_Task_07_RDV_Desc",
            localize "STR_LL_Task_07_RDV_Title",
            localize "STR_LL_Task_07_RDV_Marker"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "meet",
        false
    ] call BIS_fnc_taskCreate;

    private _varName = format ["LL_Task07_Chief_%1", round(random 100000)];
    _chief setVehicleVarName _varName;
    missionNamespace setVariable [_varName, _chief, true];
    [_chief, netId _chief, _varName, "talk"] remoteExec ["LL_fnc_task07_addAction", 0, _chief];
};

if (_mode == "talk") exitWith {
    _args params ["_chief", "_caller"];

    if ((_chief getVariable ["LL_Task_Status", "WAIT"]) != "WAIT") exitWith {};
    _chief setVariable ["LL_Task_Status", "ACTION", true];

    // Show localized subtitle without audio
    ["STR_LL_Task_07_SubtitleRdv", [], 10, false] remoteExec ["LL_fnc_radioMessage", 0];

    // --- IMMERSIVE NATIVE VOICE PATTERN ---
    private _pnjGrp = group _chief;
    private _dummy = _pnjGrp createUnit ["I_G_Soldier_F", getPos _chief, [], 0, "NONE"];
    _dummy hideObjectGlobal true;
    _dummy allowDamage false;
    _dummy disableAI "ALL";
    _pnjGrp selectLeader _chief;
    _dummy commandMove (getPos _chief getPos [500, random 360]);

    [_dummy] spawn { sleep 10; deleteVehicle (_this select 0); };

    sleep 10;

    // Enable movement
    _chief enableAI "MOVE";
    [_chief, "AmovPercMstpSrasWpstDnon"] remoteExec ["switchMove", 0];

    // Succeed RDV task
    ["task_07_rdv", "SUCCEEDED", true] call BIS_fnc_taskSetState;
    deleteMarker "mkr_task07_rdv";

    private _villagerGrp = missionNamespace getVariable ["LL_Task07_VillagerGroup", grpNull];
    private _villagers = missionNamespace getVariable ["LL_Task07_Villagers", []];
    private _militiaPos = missionNamespace getVariable ["LL_Task07_MilitiaPos", [0,0,0]];

    // Spawn enemy militia (10 to 20 units) divided into groups of 2-3 with different patrol radii
    private _numEnemies = 10 + floor (random 11);
    private _enemies = [];
    private _enemyGroups = [];
    private _tempCount = 0;

    while { _tempCount < _numEnemies } do {
        private _grpSize = (2 + floor (random 2)) min (_numEnemies - _tempCount);
        private _grp = createGroup [east, true];
        _grp setBehaviour "SAFE";
        _grp setCombatMode "RED";

        for "_g" from 1 to _grpSize do {
            sleep 1.5; // Staged delay
            private _class = selectRandom ["CUP_O_TK_Soldier", "CUP_O_TK_Soldier_GL", "CUP_O_TK_Soldier_AR"];
            private _unit = _grp createUnit [_class, _militiaPos, [], 0, "NONE"];
            _unit setPosASL _militiaPos;
            _unit allowDamage false;
            [_unit] spawn { sleep 3; (_this select 0) allowDamage true; };
            // Set courage 1 and allowFleeing 0 immediately for pre-combat patrol courage
            _unit setSkill ["courage", 1];
            _unit allowFleeing 0;
            _enemies pushBack _unit;
        };

        // All groups patrol with a radius of 50m to spread out before combat
        private _radius = 50;
        [_grp, _militiaPos, _radius] call BIS_fnc_taskPatrol;
        _enemyGroups pushBack _grp;
        _tempCount = _tempCount + _grpSize;
    };

    missionNamespace setVariable ["LL_Task07_Enemies", _enemies, true];
    missionNamespace setVariable ["LL_Task07_EnemyGroups", _enemyGroups, true];

    private _mkrMilice = "mkr_task07_milice";
    createMarker [_mkrMilice, _militiaPos];
    _mkrMilice setMarkerType "mil_objective";
    _mkrMilice setMarkerColor "ColorRed";
    _mkrMilice setMarkerText (localize "STR_LL_Task_07_Marker");

    [
        independent,
        ["task_07_milice", "task_07_rdv"],
        [
            localize "STR_LL_Task_07_Desc",
            localize "STR_LL_Task_07_Title",
            localize "STR_LL_Task_07_Marker"
        ],
        objNull,
        "ASSIGNED",
        5,
        true,
        "attack",
        false
    ] call BIS_fnc_taskCreate;

    [[], { player createDiaryRecord ["diary", [localize "STR_LL_Diary_Task07_Title", localize "STR_LL_Diary_Task07_Text"]]; }] remoteExec ["spawn", 0, true];

    // Show localized follow subtitle without audio (text message)
    ["STR_LL_Task_07_SubtitleFollow", [], 6, false] remoteExec ["LL_fnc_radioMessage", 0];

    // Order villagers to run and attack
    {
        _x setVariable ["LL_Task07_RunningToBattle", true, true];
        _x setBehaviour "AWARE";
        _x setSpeedMode "FULL";
        _x enableAI "MOVE";
        _x doMove _militiaPos;
    } forEach _villagers;

    _villagerGrp setBehaviour "AWARE";
    _villagerGrp setCombatMode "RED";
    _villagerGrp setSpeedMode "FULL";

    while { count waypoints _villagerGrp > 0 } do { deleteWaypoint [_villagerGrp, 0]; };
    private _wp = _villagerGrp addWaypoint [_militiaPos, 15];
    _wp setWaypointType "SAD";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointBehaviour "AWARE";
    _villagerGrp setCurrentWaypoint _wp;

    // Start server monitoring thread
    [_villagers, _enemies, _mkrMilice, _militiaPos, _chief] spawn {
        params ["_villagers", "_enemies", "_mkrMilice", "_militiaPos", "_chief"];

        private _initialVillagerCount = count _villagers;
        private _defeatTriggered = false;
        private _startTime = time;

        while { true } do {
            sleep 2;

            private _aliveVillagers = _villagers select { alive _x };
            private _aliveEnemies = _enemies select { alive _x };

            // Check if majority of villagers are dead
            if (count _aliveVillagers < (_initialVillagerCount / 2)) then {
                _defeatTriggered = true;
            };

            // Loop ends only when all enemies are dead
            if (count _aliveEnemies == 0) exitWith {};

            private _fightStarted = (time - _startTime) > 35;

            // Aggressive loop for allied villagers
            {
                private _villager = _x;
                _villager setSkill ["courage", 1];
                _villager allowFleeing 0;

                private _nearestEnemy = objNull;
                private _minDist = 999999;
                {
                    private _d = _x distance2D _villager;
                    if (_d < _minDist) then {
                        _minDist = _d;
                        _nearestEnemy = _x;
                    };
                } forEach _aliveEnemies;

                if (!isNull _nearestEnemy) then {
                    _villager reveal [_nearestEnemy, 4];
                    if (_fightStarted) then {
                        private _lastPush = _villager getVariable ["LL_Task07_LastPush", 0];
                        if (time - _lastPush > 8 && _minDist > 30) then {
                            _villager setVariable ["LL_Task07_LastPush", time];
                            _villager doMove (getPos _nearestEnemy);
                        };
                    };
                };
            } forEach _aliveVillagers;

            // Aggressive loop for enemies
            {
                private _enemy = _x;
                _enemy setSkill ["courage", 1];
                _enemy allowFleeing 0;

                private _targets = _aliveVillagers + (allPlayers select { alive _x });
                private _nearestTarget = objNull;
                private _minDist = 999999;
                {
                    private _d = _x distance2D _enemy;
                    if (_d < _minDist) then {
                        _minDist = _d;
                        _nearestTarget = _x;
                    };
                } forEach _targets;

                if (!isNull _nearestTarget) then {
                    _enemy reveal [_nearestTarget, 4];
                    if (_fightStarted) then {
                        private _lastPush = _enemy getVariable ["LL_Task07_LastPush", 0];
                        if (time - _lastPush > 8 && _minDist > 30) then {
                            _enemy setVariable ["LL_Task07_LastPush", time];
                            _enemy doMove (getPos _nearestTarget);
                        };
                    };
                };
            } forEach _aliveEnemies;
        };

        deleteMarker _mkrMilice;

        private _aliveVillagers = _villagers select { alive _x };
        private _rep = objNull;
        if (alive _chief) then {
            _rep = _chief;
        } else {
            if (count _aliveVillagers > 0) then { _rep = _aliveVillagers select 0; };
        };

        if (_defeatTriggered) then {
            // DEFEAT
            ["task_07_milice", "FAILED", true] call BIS_fnc_taskSetState;

            if (isNull _rep) then {
                missionNamespace setVariable ["LL_g_taskInProgress", false, true];
            } else {
                _rep setVariable ["LL_Task_Status", "READY_DEFEAT", true];

                // Isolate representative in a peaceful group to reset combat behavior
                private _safeGrp = createGroup [west, true];
                [_rep] joinSilent _safeGrp;

                _rep disableAI "MOVE";
                _rep disableAI "AUTOTARGET";
                _rep disableAI "TARGET";
                _rep disableAI "WEAPONAIM";
                _rep setUnitPos "UP";
                _rep setBehaviour "SAFE";
                _rep setCombatMode "BLUE";
                _rep action ["WeaponOnBack", _rep];
                [_rep, "AmovPercMstpSrasWpstDnon"] remoteExec ["switchMove", 0];

                private _mkrThanks = "mkr_task07_thanks";
                createMarker [_mkrThanks, getPos _rep];
                _mkrThanks setMarkerType "mil_objective";
                _mkrThanks setMarkerColor "ColorGreen";
                _mkrThanks setMarkerText (localize "STR_LL_Task_07_ActionThanks");

                [
                    independent,
                    ["task_07_thanks", "task_07_milice"],
                    [
                        localize "STR_LL_Task_07_RDV_Desc",
                        localize "STR_LL_Task_07_RDV_Title",
                        ""
                    ],
                    objNull,
                    "ASSIGNED",
                    5,
                    true,
                    "meet",
                    false
                ] call BIS_fnc_taskCreate;

                private _varName = format ["LL_Task07_Rep_%1", round(random 100000)];
                _rep setVehicleVarName _varName;
                missionNamespace setVariable [_varName, _rep, true];
                [_rep, netId _rep, _varName, "defeat"] remoteExec ["LL_fnc_task07_addAction", 0, _rep];
            };
        } else {
            // VICTORY
            if (isNull _rep) then {
                ["task_07_milice", "SUCCEEDED", true] call BIS_fnc_taskSetState;
                missionNamespace setVariable ["LL_g_taskInProgress", false, true];
            } else {
                _rep setVariable ["LL_Task_Status", "READY_THANKS", true];

                // Isolate representative in a peaceful group to reset combat behavior
                private _safeGrp = createGroup [west, true];
                [_rep] joinSilent _safeGrp;

                _rep disableAI "MOVE";
                _rep disableAI "AUTOTARGET";
                _rep disableAI "TARGET";
                _rep disableAI "WEAPONAIM";
                _rep setUnitPos "UP";
                _rep setBehaviour "SAFE";
                _rep setCombatMode "BLUE";
                _rep action ["WeaponOnBack", _rep];
                [_rep, "AmovPercMstpSrasWpstDnon"] remoteExec ["switchMove", 0];

                private _mkrThanks = "mkr_task07_thanks";
                createMarker [_mkrThanks, getPos _rep];
                _mkrThanks setMarkerType "mil_objective";
                _mkrThanks setMarkerColor "ColorGreen";
                _mkrThanks setMarkerText (localize "STR_LL_Task_07_ActionThanks");

                [
                    independent,
                    ["task_07_thanks", "task_07_milice"],
                    [
                        localize "STR_LL_Task_07_RDV_Desc",
                        localize "STR_LL_Task_07_RDV_Title",
                        ""
                    ],
                    objNull,
                    "ASSIGNED",
                    5,
                    true,
                    "meet",
                    false
                ] call BIS_fnc_taskCreate;

                private _varName = format ["LL_Task07_Rep_%1", round(random 100000)];
                _rep setVehicleVarName _varName;
                missionNamespace setVariable [_varName, _rep, true];
                [_rep, netId _rep, _varName, "thanks"] remoteExec ["LL_fnc_task07_addAction", 0, _rep];
            };
        };
    };
};

if (_mode == "complete") exitWith {
    _args params ["_rep", "_caller"];

    if ((_rep getVariable ["LL_Task_Status", ""]) != "READY_THANKS") exitWith {};
    _rep setVariable ["LL_Task_Status", "DONE", true];

    // Make representative face the player
    _rep setDir (_rep getDir _caller);
    _rep setFormDir (_rep getDir _caller);

    // Force weapon to back and play talking animation
    _rep action ["WeaponOnBack", _rep];
    [_rep, "Acts_CivilTalking_1"] remoteExec ["switchMove", 0];

    // Show subtitle message (stays on screen for 10 seconds)
    ["STR_LL_Task_07_SubtitleThanks", [], 10, false] remoteExec ["LL_fnc_radioMessage", 0];

    // Spawn a thread to handle the speech duration, task completion, and then the flight
    [_rep] spawn {
        params ["_rep"];
        
        // Wait 10 seconds for the dialogue animation and speech to finish
        sleep 10;
        
        // Reset animation to standing alert state before running
        [_rep, "AmovPercMstpSrasWpstDnon"] remoteExec ["switchMove", 0];
        sleep 0.5;

        // Succeed tasks
        ["task_07_thanks", "SUCCEEDED", true] call BIS_fnc_taskSetState;
        ["task_07_milice", "SUCCEEDED", true] call BIS_fnc_taskSetState;
        deleteMarker "mkr_task07_thanks";

        // Now trigger the flight and dissolution
        private _villagers = missionNamespace getVariable ["LL_Task07_Villagers", []];
        private _aliveVillagers = _villagers select { alive _x };

        if (count _aliveVillagers > 0) then {
            private _dissolveGrp = createGroup [west, true];
            {
                _x enableAI "MOVE";
                _x enableAI "AUTOTARGET";
                _x enableAI "TARGET";
                _x enableAI "WEAPONAIM";
                _x setUnitPos "UP";
                _x setBehaviour "SAFE";
                _x setSpeedMode "LIMITED";
                [_x, "AmovPercMstpSrasWpstDnon"] remoteExec ["switchMove", 0];
                _x action ["WeaponOnBack", _x];
            } forEach _aliveVillagers;
            _aliveVillagers joinSilent _dissolveGrp;

            [_aliveVillagers, _dissolveGrp] spawn {
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
                    _wp setWaypointSpeed "LIMITED";
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

        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    };
};

if (_mode == "complete_defeat") exitWith {
    _args params ["_rep", "_caller"];

    if ((_rep getVariable ["LL_Task_Status", ""]) != "READY_DEFEAT") exitWith {};
    _rep setVariable ["LL_Task_Status", "DONE", true];

    // Make representative face the player
    _rep setDir (_rep getDir _caller);
    _rep setFormDir (_rep getDir _caller);

    // Force weapon to back and play talking animation
    _rep action ["WeaponOnBack", _rep];
    [_rep, "Acts_CivilTalking_2"] remoteExec ["switchMove", 0];

    // Show defeat subtitle message (stays on screen for 10 seconds)
    ["STR_LL_Task_07_SubtitleDefeat", [], 10, false] remoteExec ["LL_fnc_radioMessage", 0];

    [_rep] spawn {
        params ["_rep"];

        // Wait 10 seconds for speech to finish
        sleep 10;

        // Reset animation before running
        [_rep, "AmovPercMstpSrasWpstDnon"] remoteExec ["switchMove", 0];
        sleep 0.5;

        ["task_07_thanks", "SUCCEEDED", true] call BIS_fnc_taskSetState;
        deleteMarker "mkr_task07_thanks";

        private _villagers = missionNamespace getVariable ["LL_Task07_Villagers", []];
        private _aliveVillagers = _villagers select { alive _x };

        if (count _aliveVillagers > 0) then {
            private _dissolveGrp = createGroup [west, true];
            {
                _x enableAI "MOVE";
                _x enableAI "AUTOTARGET";
                _x enableAI "TARGET";
                _x enableAI "WEAPONAIM";
                _x setUnitPos "UP";
                _x setBehaviour "SAFE";
                _x setSpeedMode "LIMITED";
                [_x, "AmovPercMstpSrasWpstDnon"] remoteExec ["switchMove", 0];
                _x action ["WeaponOnBack", _x];
            } forEach _aliveVillagers;
            _aliveVillagers joinSilent _dissolveGrp;

            [_aliveVillagers, _dissolveGrp] spawn {
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
                    _wp setWaypointSpeed "LIMITED";
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

        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    };
};
