if (!isServer) exitWith {};

private _fnSetState = {
    params ["_s"];
    missionNamespace setVariable ["LL_HELI_state", _s, true];
    diag_log format ["[LL][HELI_MGR] État → %1", _s];
};

private _fnInitState = {

    ["IDLE"] call _fnSetState;
    missionNamespace setVariable ["LL_HELI_type",     "",      true];
    missionNamespace setVariable ["LL_HELI_priority", 0,       true];
    missionNamespace setVariable ["LL_HELI_caller",   objNull, true];
    missionNamespace setVariable ["LL_HELI_obj",      objNull, true];
    missionNamespace setVariable ["LL_HELI_cargo",    objNull, true];
    missionNamespace setVariable ["LL_HELI_group",    grpNull, true];
    missionNamespace setVariable ["LL_HELI_crew",     [],      true];
    missionNamespace setVariable ["LL_HELI_abort",    false,   false];
    missionNamespace setVariable ["LL_missionHelicopter", objNull, true];
    missionNamespace setVariable ["TAG_AirSupport_Active",  false, true];
};

private _fnAborted = {
    missionNamespace getVariable ["LL_HELI_abort", false]
};

private _fnGetSpawnPos = {
    params ["_targetPos", "_height"];
    
    private _alivePlayers = allPlayers select { alive _x };
    private _spawnRadius = 2500;
    private _foundPos = [];
    private _mapSize = worldSize;
    
    while { count _foundPos == 0 && _spawnRadius <= 8000 } do {
        private _attempts = 0;
        while { _attempts < 30 && count _foundPos == 0 } do {
            private _angle = random 360;
            private _testPos = _targetPos getPos [_spawnRadius, _angle];
            _testPos set [2, 350]; 
            
            if ((_testPos select 0) > 0 && (_testPos select 0) < _mapSize && (_testPos select 1) > 0 && (_testPos select 1) < _mapSize) then {
                private _tooClose = false;
                {
                    if (_x distance2D _testPos < 2000) exitWith { _tooClose = true; };
                } forEach _alivePlayers;
                
                if (!_tooClose) then { _foundPos = _testPos; };
            };
            _attempts = _attempts + 1;
        };
        if (count _foundPos == 0) then { _spawnRadius = _spawnRadius + 500; };
    };
    
    if (count _foundPos == 0) then {
        private _angle = random 360;
        _foundPos = _targetPos getPos [2500, _angle];
        _foundPos set [2, 350];
    };
    
    _foundPos
};

private _fnGetLZ = {

    params ["_caller", "_type"];
    private _lzPos = getPosATL _caller;
    if (_type in ["LIVRAISON", "VEHICULE", "DEBARQUEMENT", "EMBARQUEMENT"]) then {
        private _heliports = (allMissionObjects "") select {
            (toLower (vehicleVarName _x)) regexMatch "heliport_\d+"
        };
        if (count _heliports > 0) then {
            private _ref     = getPosATL _caller;
            private _nearest = _heliports # 0;
            private _minD    = _nearest distance2D _ref;
            {
                private _d = _x distance2D _ref;
                if (_d < _minD) then { _minD = _d; _nearest = _x; };
            } forEach _heliports;
            _lzPos = getPos _nearest;
            diag_log format ["[LL][HELI_MGR] LZ: '%1' à %2m", vehicleVarName _nearest, round _minD];
        } else {
            diag_log "[LL][HELI_MGR][WARN] Aucun héliport trouvé — fallback position caller.";
        };
    };
    _lzPos
};

private _fnCreateMarker = {
    params ["_type", "_pos"];
    private _data = switch (_type) do {
        case "LIVRAISON":    { ["mil_box",     "ColorBlue",   localize "STR_TAG_Marker_Heli_Ammo"]    };
        case "VEHICULE":     { ["mil_box",     "ColorBlue",   localize "STR_TAG_Marker_Heli_Vehicle"] };
        case "DEBARQUEMENT": { ["mil_end",     "ColorGreen",  localize "STR_TAG_Marker_Heli_Debark"]  };
        case "EMBARQUEMENT": { ["mil_pickup",  "ColorYellow", localize "STR_TAG_Marker_Heli_Extract"] };
        case "CAS":          { ["mil_warning", "ColorRed",    localize "STR_TAG_Marker_Heli_CAS"]     };
        default              { ["mil_dot",     "ColorBlack",  ""]                                     };
    };
    private _name = format ["heli_%1_%2", _type, floor (random 100000)];
    private _mrk  = createMarker [_name, _pos];
    _mrk setMarkerType  (_data # 0);
    _mrk setMarkerColor (_data # 1);
    _mrk setMarkerText  (_data # 2);

    if (_type == "CAS") then {
        private _areaName = _name + "_area";
        private _mrkArea = createMarker [_areaName, _pos];
        _mrkArea setMarkerShape "ELLIPSE";

        _mrkArea setMarkerSize [200, 200];
        _mrkArea setMarkerColor "ColorRed";
        _mrkArea setMarkerAlpha 0.3;
        _mrkArea setMarkerBrush "SolidBorder";
    };

    _name
};

private _fnSpawnHeli = {

    params ["_spawnPos", "_targetPos", "_flyHeight"];
    ["SPAWNING"] call _fnSetState;

    private _heli  = objNull;
    private _tries = 0;
    while { isNull _heli && { _tries < 5 } } do {
        _tries = _tries + 1;
        _heli = createVehicle ["CUP_I_UH60L_FFV_RACS", _spawnPos, [], 0, "FLY"];
        if (!isNull _heli) then {
            _heli setPos      _spawnPos;
            _heli setDir      (_spawnPos getDir _targetPos);
            _heli flyInHeight _flyHeight;
            _heli allowDamage false;
            _heli setFuel 1;
        } else { sleep 1; };
    };

    if (isNull _heli) exitWith {
        diag_log "[LL][HELI_MGR][ERROR] Création hélicoptère échouée après 5 tentatives.";
        []
    };

    createVehicleCrew _heli;
    sleep 0.3;
    _heli setVehicleAmmo 1;

    private _crew    = crew _heli;
    private _group   = group (_crew # 0);
    private _pilot   = driver _heli;
    private _copilot = _heli turretUnit [0];
    private _gunners = _crew select { _x != _pilot && { _x != _copilot } };

    _group setBehaviour  "CARELESS";
    _group setCombatMode "RED";
    _group setSpeedMode  "FULL";

    { _x disableAI "FSM"; _x allowDamage false; } forEach [_pilot, _copilot];

    {
        private _g = _x;
        _g allowDamage  false;
        _g allowFleeing 0;
        {
            _g setSkill [_x, 1.0];
        } forEach ["aimingAccuracy","aimingShake","aimingSpeed","spotDistance","spotTime","courage","commanding"];
    } forEach _gunners;

    missionNamespace setVariable ["LL_HELI_obj",   _heli,  true];
    missionNamespace setVariable ["LL_HELI_group",  _group, true];
    missionNamespace setVariable ["LL_HELI_crew",   _crew,  true];
    missionNamespace setVariable ["LL_missionHelicopter", _heli, true];
    missionNamespace setVariable ["TAG_AirSupport_Active", true, true];

    diag_log format ["[LL][HELI_MGR] Hélicoptère créé. Équipage: %1 membre(s).", count _crew];
    [_heli, _crew, _group]
};

private _fnApproach = {

    params ["_heli", "_group", "_targetPos", "_flyHeight"];
    ["APPROACHING"] call _fnSetState;

    _heli flyInHeight _flyHeight;
    _heli limitSpeed  200;

    while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };
    private _wp = _group addWaypoint [_targetPos, 0];
    _wp setWaypointType       "MOVE";
    _wp setWaypointBehaviour  "CARELESS";
    _wp setWaypointCombatMode "RED";
    _wp setWaypointSpeed      "FULL";
    _heli doMove _targetPos;

    private _timer = 0;
    private _abort = false;
    waitUntil {
        sleep 1; _timer = _timer + 1;
        _abort = call _fnAborted;
        (_heli distance2D _targetPos < 200) || _timer > 180 || !alive _heli || _abort
    };

    while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };

    if (!_abort && _timer <= 180 && alive _heli) then {
        _group setBehaviour  "CARELESS";
        _group setCombatMode "BLUE";
        _group setSpeedMode  "FULL";
    };
    _abort
};

private _fnRTB = {

    params [
        "_heli", "_group", "_crew", "_homeBase", "_flyHeight",
        ["_withCargo",        false],
        ["_applyCASCooldown", false]
    ];

    if (_withCargo) then { ["RTB_WITH_CARGO"] call _fnSetState; } else { ["RTB"] call _fnSetState; };

    missionNamespace setVariable ["TAG_AirSupport_Active", false, true];

    while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };

    if (alive _heli) then {
        _heli flyInHeight _flyHeight;
        _heli limitSpeed  300;
        private _rtbDest = _homeBase;
        private _wpRTB = _group addWaypoint [_rtbDest, 0];
        _wpRTB setWaypointType       "MOVE";
        _wpRTB setWaypointBehaviour  "CARELESS";
        _wpRTB setWaypointCombatMode "RED";
        _wpRTB setWaypointSpeed      "FULL";
        _group setCurrentWaypoint _wpRTB;
        _heli doMove _rtbDest;

        private _rtbStart = time;
        waitUntil {
            sleep 5;
            private _playersSafe = ({ _x distance2D _heli < 1200 } count allPlayers) == 0;
            ((_heli distance2D _rtbDest < 100) && _playersSafe) || !alive _heli || call _fnAborted
        };

        while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };
    };

    if (_withCargo) then {
        private _cargo = missionNamespace getVariable ["LL_HELI_cargo", objNull];
        if (!isNull _cargo) then {
            { ropeDestroy _x; } forEach (ropes _heli);
            sleep 0.3;
            if (!isNull _cargo && { !isNull _cargo }) then { deleteVehicle _cargo; };
            missionNamespace setVariable ["LL_HELI_cargo", objNull, true];
        };
        ["STR_LL_Heli_Msg_CargoAborted"] remoteExec ["LL_fnc_radioMessage", 0];
    };

    if (alive _heli) then {
        { deleteVehicle _x; } forEach (crew _heli);
        deleteVehicle _heli;
    };
    if (!isNull _group) then { deleteGroup _group; };

    if (_applyCASCooldown) then {
        missionNamespace setVariable ["TAG_CAS_Cooldown_Until", time + 300, true];
        diag_log "[LL][HELI_MGR] Cooldown CAS appliqué (300s).";
    };

    diag_log "[LL][HELI_MGR] RTB + nettoyage terminés.";
};

private _fnExecCAS = {

    params ["_heli", "_group", "_caller", "_targetPos", "_loiterHeight", "_loiterRadius", "_loiterDuration"];
    ["CAS"] call _fnSetState;

    _heli flyInHeight    _loiterHeight;
    _heli flyInHeightASL [_loiterHeight, _loiterHeight, _loiterHeight];
    _heli limitSpeed 80;

    while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };
    private _wpCAS = _group addWaypoint [_targetPos, 0];
    _wpCAS setWaypointType         "LOITER";
    _wpCAS setWaypointLoiterType   "CIRCLE";
    _wpCAS setWaypointLoiterRadius _loiterRadius;
    _wpCAS setWaypointBehaviour    "CARELESS";
    _wpCAS setWaypointCombatMode   "RED";
    _wpCAS setWaypointSpeed        "LIMITED";
    _heli doMove _targetPos;

    waitUntil {
        sleep 1;
        !alive _heli || (_heli distance2D _targetPos < (_loiterRadius + 150)) || call _fnAborted
    };

    ["STR_LL_Heli_Msg_Active"] remoteExec ["LL_fnc_radioMessage", _caller];

    private _endTime    = time + _loiterDuration;
    private _lastReveal = 0;
    private _abort      = false;

    while { time < _endTime && { alive _heli } && { !_abort } } do {
        sleep 1;
        _abort = call _fnAborted;
        if (time - _lastReveal >= 5) then {
            _lastReveal = time;
            {
                if (side (group _x) == east) then { _group reveal [_x, 4]; };
            } forEach (_heli nearEntities [["Man","Car","Tank"], 800]);
        };
    };

    while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };
    _abort
};

private _fnExecDelivery = {

    params ["_heli", "_group", "_crew", "_caller", "_type", "_targetPos", "_hoverHeight", "_side"];
    ["DELIVERING"] call _fnSetState;

    if (_type == "VEHICULE") then { _hoverHeight = 10; };

    private _cargoClass = "B_supplyCrate_F";
    if (_type == "VEHICULE") then {
        _cargoClass = "CUP_I_LR_MG_RACS";
    };

    private _cargo = createVehicle [_cargoClass, [0,0,0], [], 0, "NONE"];
    _cargo setPos   (_heli modelToWorld [0,0,-15]);
    _cargo allowDamage false;
    private _origMass = getMass _cargo;
    _cargo setMass (if (_type == "LIVRAISON") then { 500 } else { 800 });
    _heli setSlingLoad _cargo;
    missionNamespace setVariable ["LL_HELI_cargo", _cargo, true];

    if (_type == "LIVRAISON") then {
        clearWeaponCargoGlobal   _cargo;
        clearMagazineCargoGlobal _cargo;
        clearItemCargoGlobal     _cargo;
        clearBackpackCargoGlobal _cargo;

        private _allWeapons = []; private _allMags = []; private _allItems = []; private _allPacks = [];
        {
            { if (_x != "") then {
                _allWeapons pushBackUnique _x;
                private _mags = getArray (configFile >> "CfgWeapons" >> _x >> "magazines");
                if (count _mags > 0) then { _allMags pushBackUnique (_mags # 0); };
                if (count _mags > 1) then { _allMags pushBackUnique (_mags # 1); };
            }; } forEach [primaryWeapon _x, secondaryWeapon _x, handgunWeapon _x];
            { _allMags  pushBackUnique _x; } forEach (magazines _x);
            {
                if (_x in ["ItemGPS","ItemDetector","ToolKit","MineDetector","B_UavTerminal"]) then {
                    _allItems pushBackUnique _x;
                };
            } forEach (items _x + assignedItems _x);
            if (backpack _x != "") then { _allPacks pushBackUnique (backpack _x); };
        } forEach (allUnits select { alive _x && { side (group _x) == _side } });

        { _cargo addWeaponCargoGlobal [_x, 2]; } forEach _allWeapons;
        {
            private _qty = if (
                (toLower _x find "grenade") != -1 ||
                (toLower _x find "shell")   != -1 ||
                (toLower _x find "smoke")   != -1
            ) then { 10 } else { 15 };
            _cargo addMagazineCargoGlobal [_x, _qty];
        } forEach _allMags;
        { _cargo addBackpackCargoGlobal [_x, 2]; } forEach _allPacks;
        { _cargo addItemCargoGlobal     [_x, 2]; } forEach _allItems;
        _cargo addItemCargoGlobal     ["FirstAidKit",      20];
        _cargo addMagazineCargoGlobal ["SmokeShell",       10];
        _cargo addMagazineCargoGlobal ["SmokeShellGreen",  10];
    };

    if (_type == "VEHICULE") then {
        clearWeaponCargoGlobal   _cargo;
        clearMagazineCargoGlobal _cargo;
        clearItemCargoGlobal     _cargo;
        clearBackpackCargoGlobal _cargo;

        private _leader = missionNamespace getVariable ["player_00", objNull];
        if (!isNull _leader) then {
            private _uniqueMags = [];
            {
                if (alive _x) then {
                    if (primaryWeapon _x != "") then {
                        private _comp = [primaryWeapon _x] call BIS_fnc_compatibleMagazines;
                        if (count _comp > 0) then { _uniqueMags pushBackUnique (_comp select 0); };
                    };
                    if (secondaryWeapon _x != "") then {
                        private _comp = [secondaryWeapon _x] call BIS_fnc_compatibleMagazines;
                        if (count _comp > 0) then { _uniqueMags pushBackUnique (_comp select 0); };
                    };
                    if (handgunWeapon _x != "") then {
                        private _comp = [handgunWeapon _x] call BIS_fnc_compatibleMagazines;
                        if (count _comp > 0) then { _uniqueMags pushBackUnique (_comp select 0); };
                    };
                };
            } forEach (units group _leader);

            {
                _cargo addMagazineCargoGlobal [_x, 3];
            } forEach _uniqueMags;
        };
    };

    _heli flyInHeight _hoverHeight;
    _heli flyInHeightASL [_hoverHeight, _hoverHeight, _hoverHeight];

    while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };
    private _wp2 = _group addWaypoint [_targetPos, 0];
    _wp2 setWaypointType      "MOVE";
    _wp2 setWaypointBehaviour "CARELESS";
    _wp2 setWaypointSpeed     "FULL";
    _heli doMove _targetPos;

    private _apTimer = 0;
    private _abort   = false;
    waitUntil {
        sleep 0.5; _apTimer = _apTimer + 0.5;
        _abort = call _fnAborted;
        (_heli distance2D _targetPos < 5) || _apTimer > 30 || !alive _heli || !alive _cargo || _abort
    };
    while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };

    if (_abort) exitWith { true };

    if (!alive _heli || !alive _cargo) exitWith {
        if (!isNull _cargo && { !isNull _cargo }) then { deleteVehicle _cargo; };
        missionNamespace setVariable ["LL_HELI_cargo", objNull, true];
        false
    };

    if (_type == "VEHICULE") then {
        private _enemies = _targetPos nearEntities [["Man", "Car", "Tank"], 50] select { side _x == east };
        if (count _enemies > 0) then {
            _abort = true;
            "La LZ n'est pas sécurisée ! Retour à la base." remoteExec ["systemChat", _caller];
        };
    };

    if (_abort) exitWith { true };

    doStop _heli;
    private _minH        = if (_type == "VEHICULE") then { 3 } else { 5 };
    private _cargoThresh = if (_type == "VEHICULE") then { 0.5 } else { 3 };
    private _heliThresh  = if (_type == "VEHICULE") then { 3 } else { 4 };
    private _descTimer   = 0;

    waitUntil {
        sleep 0.5; _descTimer = _descTimer + 0.5;
        _abort = call _fnAborted;
        if (_abort) exitWith { true };
        private _newH = (_hoverHeight - _descTimer) max _minH;
        _heli flyInHeight _newH;
        _heli flyInHeightASL [_newH, _newH, _newH];
        private _cargoH = getPosATL _cargo select 2;
        private _heliH  = getPosATL _heli  select 2;
        _cargoH < _cargoThresh || _heliH < _heliThresh || _descTimer > 30 || !alive _heli || !alive _cargo || _abort
    };

    if (_abort) exitWith { true };

    if (!alive _heli || !alive _cargo) exitWith {
        if (!isNull _cargo && { !isNull _cargo }) then { deleteVehicle _cargo; };
        missionNamespace setVariable ["LL_HELI_cargo", objNull, true];
        false
    };

    sleep 0.5;
    { ropeDestroy _x; } forEach (ropes _heli);
    _heli setSlingLoad objNull;
    sleep 0.5;
    _cargo setVelocity [0,0,0];
    _cargo setVectorUp [0,0,1];
    _cargo setMass     _origMass;
    _cargo allowDamage true;
    missionNamespace setVariable ["LL_HELI_cargo", objNull, true];

    if (_type == "LIVRAISON") then {
        ["STR_TAG_Msg_Ammo_Dropped"] remoteExec ["LL_fnc_radioMessage", _caller];
        [_cargo] remoteExec ["LL_fnc_addResupplyAction", 0, true];

        [_cargo] spawn {
            params ["_crate"];
            if (isNull _crate) exitWith {};
            private _smoke = createVehicle ["SmokeShellGreen", getPos _crate, [], 0, "CAN_COLLIDE"];
            private _dead = false;
            for "_i" from 1 to 59 do {
                sleep 10;
                if (!alive _crate) exitWith { _dead = true; };
            };
            if (_dead) exitWith {
                if (!isNull _smoke && { alive _smoke }) then { deleteVehicle _smoke; };
            };
            if (alive _crate) then {
                private _smks = [];
                for "_d" from 0 to 315 step 45 do {
                    _smks pushBack (createVehicle ["SmokeShell", (_crate getPos [2, _d]), [], 0, "CAN_COLLIDE"]);
                };
                sleep 10;
                if (alive _crate)                          then { deleteVehicle _crate; };
                if (!isNull _smoke && { alive _smoke })    then { deleteVehicle _smoke; };
                sleep 120;
                { if (!isNull _x && { alive _x }) then { deleteVehicle _x; }; } forEach _smks;
            };
        };
    } else {
        ["STR_TAG_Msg_Vehicle_Dropped"] remoteExec ["LL_fnc_radioMessage", _caller];

        missionNamespace setVariable ["vehicule_team", _cargo, true];
    };

    false  
};

private _fnExecDeploy = {

    params ["_heli", "_group", "_crew", "_caller", "_targetPos", "_homeBase", "_side"];
    ["DEPLOYING"] call _fnSetState;

    _heli flyInHeight 75;
    while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };
    private _wpDeb = _group addWaypoint [_targetPos, 0];
    _wpDeb setWaypointType       "MOVE";
    _wpDeb setWaypointBehaviour  "CARELESS";
    _wpDeb setWaypointCombatMode "BLUE";
    _wpDeb setWaypointSpeed      "LIMITED";
    _heli doMove _targetPos;

    private _hovTimer = 0;
    waitUntil {
        sleep 0.5; _hovTimer = _hovTimer + 0.5;
        !alive _heli || (_heli distance2D _targetPos < 30) || _hovTimer > 90
    };
    if (!alive _heli) exitWith {};

    while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };
    private _tDir      = _targetPos getDir _homeBase;
    private _transitWP = _group addWaypoint [(_targetPos getPos [400, _tDir]), 0];
    _transitWP setWaypointType "MOVE";
    _heli doMove (_targetPos getPos [400, _tDir]);

    private _vests      = ["CUP_V_JPC_medical_coy","CUP_V_JPC_tl_coy","CUP_V_JPC_weapons_coy",
                           "CUP_V_JPC_communicationsbelt_coy","CUP_V_JPC_Fastbelt_coy",
                           "CUP_V_JPC_lightbelt_coy","CUP_V_JPC_medicalbelt_coy",
                           "CUP_V_JPC_tlbelt_coy","CUP_V_JPC_weaponsbelt_coy"];
    private _helmets    = ["CUP_H_OpsCore_Tan_SF","CUP_H_OpsCore_Tan","CUP_H_OpsCore_Tan_NohS",
                           "CUP_H_OpsCore_Grey_SF","CUP_H_OpsCore_Grey","CUP_H_OpsCore_Grey_NohS"];
    private _backpacks  = ["CUP_B_AssaultPack_Coyote","B_assaultPack_cbr","B_Kitbag_cbr"];
    private _uniforms   = ["CUP_U_B_USMC_MCCUU_des_gloves","CUP_U_B_USMC_MCCUU_des_roll_2",
                           "CUP_U_B_USMC_MCCUU_des_roll_2_gloves","CUP_U_B_USMC_MCCUU_des_roll_pads",
                           "CUP_U_B_USMC_MCCUU_des_pads","CUP_U_B_USMC_MCCUU_des_pads_gloves",
                           "CUP_U_B_USMC_MCCUU_des_roll","CUP_U_B_USMC_MCCUU_des_roll_gloves",
                           "CUP_U_B_USMC_MCCUU_des"];
    private _cagoules   = ["CUP_G_Tan_Scarf_GPS","CUP_G_TK_RoundGlasses_blk","CUP_G_Oakleys_Drk",
                           "CUP_G_Scarf_Face_Tan","G_Aviator","CUP_G_ESS_KHK_Facewrap_Tan","G_Bandana_khk"];

    private _pendingDead = [];
    if (isMultiplayer && !isNil "LL_g_deadPlayers") then {
        _pendingDead = LL_g_deadPlayers select { !isNull _x && !alive _x };
    };

    private _availableTypes = [
        "CUP_I_RACS_Soldier_SL",
        "CUP_I_RACS_Soldier_Medic",
        "CUP_I_RACS_Soldier_MG",
        "CUP_I_RACS_Soldier_LAT",
        "CUP_I_RACS_Soldier"
    ];
    private _unitTypes = if (!isMultiplayer) then {
        _availableTypes
    } else {
        private _num = (count _pendingDead) max 2;
        private _t = [];
        for "_i" from 0 to (_num - 1) do { _t pushBack (_availableTypes select (_i mod count _availableTypes)); };
        _t
    };

    private _fnAddMags = {
        params ["_u","_w","_n"];
        if (_w == "") exitWith {};
        private _mags = getArray (configFile >> "CfgWeapons" >> _w >> "magazines");
        if (count _mags > 0) then { for "_i" from 1 to _n do { _u addItem (_mags # 0); }; };
    };

    private _infGroup       = createGroup [_side, true];
    private _reinforcements = [];

    {
        private _unitType = _x;
        private _unit     = _infGroup createUnit [_unitType, _targetPos, [], 0, "NONE"];

        private _vestPool = switch (true) do {
            case (_unitType == "CUP_I_RACS_Soldier_Medic"): {
                private _p = _vests select { _x find "medical" != -1 };
                if (count _p > 0) then { _p } else { _vests }
            };
            case (_unitType == "CUP_I_RACS_Soldier_SL"): {
                private _p = _vests select { _x find "_tl" != -1 };
                if (count _p > 0) then { _p } else { _vests }
            };
            default { _vests };
        };

        removeUniform _unit; removeVest _unit; removeBackpack _unit;
        removeHeadgear _unit; removeGoggles _unit;
        removeAllWeapons _unit; 

        _unit forceAddUniform (selectRandom _uniforms);
        [_unit, "CSAT_ScimitarRegiment"] call BIS_fnc_setUnitInsignia;
        _unit addVest     (selectRandom _vestPool);
        _unit addBackpack (selectRandom _backpacks);
        _unit addHeadgear (selectRandom _helmets);
        _unit addGoggles  (selectRandom _cagoules);
        _unit linkItem "NVGogglesB_blk_F";

        private _refUnit = missionNamespace getVariable ["LL_HELI_caller", objNull];
        if (isNull _refUnit) then { _refUnit = missionNamespace getVariable ["player_00", objNull]; };

        if (!isNull _refUnit) then {
            private _pw = primaryWeapon _refUnit;
            if (_pw != "") then {
                [_unit, _pw, 5] call _fnAddMags;
                _unit addWeapon _pw;
            };
            private _hw = handgunWeapon _refUnit;
            if (_hw != "") then {
                [_unit, _hw, 3] call _fnAddMags;
                _unit addWeapon _hw;
            };

        } else {

            [_unit, "CUP_arifle_FAMAS_F1", 5] call _fnAddMags;
            _unit addWeapon "CUP_arifle_FAMAS_F1";
        };

        _unit addWeapon "CUP_LRTV";

        if (!isNil "LL_g_allNamesTyped") then {
            private _used = missionNamespace getVariable ["LL_g_usedPlayerNames", []];
            private _available = LL_g_allNamesTyped select { !((_x select 0 select 0) in _used) };
            if (_available isEqualTo []) then { _available = LL_g_allNamesTyped; };
            private _entry = selectRandom _available;
            private _nameData = _entry select 0;
            private _faceType = _entry select 1;

            _used pushBack (_nameData select 0);
            missionNamespace setVariable ["LL_g_usedPlayerNames", _used];

            private _faces = switch (_faceType) do {
                case "Black":     { ["AfricanHead_01","AfricanHead_02","AfricanHead_03"] };
                case "Arab":      { ["PersianHead_A3_01","PersianHead_A3_02","PersianHead_A3_03","GreekHead_A3_01","GreekHead_A3_02","GreekHead_A3_03","GreekHead_A3_04","GreekHead_A3_05","GreekHead_A3_06"] };
                case "Asian":     { ["AsianHead_A3_01","AsianHead_A3_02","AsianHead_A3_03"] };
                case "Pacific":   { ["TanoanHead_A3_01","TanoanHead_A3_02","TanoanHead_A3_03","TanoanHead_A3_04","TanoanHead_A3_05"] };
                default           { ["WhiteHead_01","WhiteHead_02","WhiteHead_03","WhiteHead_04","WhiteHead_05","WhiteHead_06","WhiteHead_07","WhiteHead_08","WhiteHead_09","WhiteHead_10","WhiteHead_11","WhiteHead_12","WhiteHead_13","WhiteHead_14","WhiteHead_15","WhiteHead_16","WhiteHead_17","WhiteHead_18","WhiteHead_19","WhiteHead_20","WhiteHead_21"] };
            };
            private _face = selectRandom _faces;
            private _speaker = switch (_faceType) do {
                case "White": { selectRandom ["Male01ENG", "Male02ENG", "Male03ENG", "Male04ENG"] };
                case "Black": { selectRandom ["Male05ENG", "Male06ENG", "Male07ENG"] };
                default { selectRandom ["Male08ENG", "Male09ENG", "Male10ENG", "Male11ENG", "Male12ENG"] };
            };
            private _pitch = 0.90 + random 0.20;

            [_unit, _nameData, _face, _speaker, _pitch, ""] remoteExec ["LL_fnc_applyIdentity", 0, _unit];
            _unit setVariable ["LL_s_identity", [_nameData, _faceType, _face, _speaker, _pitch, ""], true];
            _unit setVariable ["LL_IdentitySet", true, true];

            if (!isNil "LL_fnc_setupUVO") then { [_unit] call LL_fnc_setupUVO; };
        };

        for "_i" from 1 to 3 do { _unit addItem "FirstAidKit"; };
        for "_i" from 1 to 3 do { _unit addItem "CUP_HandGrenade_M67"; };
        for "_i" from 1 to 3 do { _unit addItem "SmokeShell"; };
        if (_unitType == "CUP_I_RACS_Soldier_Medic") then { _unit addItemToBackpack "Medikit"; };

        _unit setUnitRank (switch (_unitType) do {
            case "CUP_I_RACS_Soldier_SL":    { "SERGEANT" };
            case "CUP_I_RACS_Soldier_Medic": { "CORPORAL"  };
            default                          { "PRIVATE"   };
        });

        _unit moveInCargo _heli;
        _reinforcements pushBack _unit;
    } forEach _unitTypes;

    sleep 1;
    ["STR_LL_Heli_Msg_Landed_Reinforce"] remoteExec ["LL_fnc_radioMessage", _caller];

    private _origBPs = [];
    {
        _origBPs pushBack (backpack _x);
        if (backpack _x != "") then { removeBackpack _x; };
        _x addBackpack "B_Parachute";
    } forEach _reinforcements;

    {
        unassignVehicle _x; moveOut _x; sleep 0.4;
        _x action ["OpenParachute", _x]; sleep 0.6;
    } forEach _reinforcements;

    private _unloadTimer = 0;
    waitUntil {
        sleep 1; _unloadTimer = _unloadTimer + 1;
        !alive _heli || ({ _x in _heli } count _reinforcements == 0) || _unloadTimer > 30
    };

    private _paraTimeout = time + 45;
    waitUntil {
        sleep 1;
        time > _paraTimeout || { _reinforcements select { alive _x && { getPosATL _x # 2 > 0.5 } } isEqualTo [] }
    };

    {
        if (alive _x) then {
            removeBackpack _x;
            private _bp = _origBPs # _forEachIndex;
            if (_bp != "") then { _x addBackpack _bp; };
        };
    } forEach _reinforcements;

    private _playerGroup = if (!isNull _caller) then { group _caller } else { grpNull };

    if (isMultiplayer && count _pendingDead > 0) then {
        {
            private _aiUnit = _x;
            private _aiIdx  = _forEachIndex;
            if (_aiIdx < count _pendingDead) then {
                private _deadPlayer = _pendingDead select _aiIdx;
                if (!isNull _deadPlayer && !alive _deadPlayer) then {
                    [_aiUnit] remoteExec ["selectPlayer", _deadPlayer];
                    [netId _deadPlayer] call LL_fnc_unregisterDeadPlayer;
                    ["Vous avez rejoint un renfort. Retournez au combat."] remoteExec ["systemChat", _deadPlayer];
                    _aiUnit allowDamage false;
                    [_aiUnit] spawn { sleep 3; (_this select 0) allowDamage true; };
                };
            };
        } forEach _reinforcements;
    };

    if (!isNull _playerGroup) then {
        [_reinforcements, _playerGroup] remoteExec ["joinSilent", groupOwner _playerGroup];
        ["STR_LL_Heli_Msg_Squad_Joined"] remoteExec ["LL_fnc_radioMessage", _caller];
    } else {
        [_infGroup, _targetPos, 150] call BIS_fnc_taskPatrol;
        ["STR_LL_Heli_Msg_Patrol_Started"] remoteExec ["LL_fnc_radioMessage", 0];
    };
};

private _fnExecExtract = {

    params ["_heli", "_group", "_crew", "_caller", "_targetPos", "_homeBase", "_flyHeight"];
    ["EXTRACTING"] call _fnSetState;

    private _hostaged = missionNamespace getVariable ["LL_Task02b_Hostage", objNull];
    private _isTask02bActive = !isNull _hostaged && { alive _hostaged } && { !(missionNamespace getVariable ["LL_Task02b_Freed_Done", false]) };
    if (_isTask02bActive) then {
        ["task_02b_informateur", _targetPos] call BIS_fnc_taskSetDestination;

        deleteMarker "LL_mkr_t02b_extraction"; 
        private _extMkr = createMarker ["LL_mkr_t02b_extraction", _targetPos];
        _extMkr setMarkerType "mil_pickup";
        _extMkr setMarkerColor "ColorYellow";
        _extMkr setMarkerText (localize "STR_TAG_Marker_Heli_Extract");
    };

    _heli flyInHeight 15;
    _heli flyInHeightASL [15, 15, 15];
    while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };
    private _wpEmb = _group addWaypoint [_targetPos, 0];
    _wpEmb setWaypointType       "MOVE";
    _wpEmb setWaypointBehaviour  "CARELESS";
    _wpEmb setWaypointCombatMode "BLUE";
    _wpEmb setWaypointSpeed      "FULL";
    _heli doMove _targetPos;

    private _posTimer = 0;
    waitUntil {
        sleep 0.5; _posTimer = _posTimer + 0.5;
        (_heli distance2D _targetPos < 5) || _posTimer > 30 || !alive _heli
    };
    if (!alive _heli) exitWith { false };
    while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };

    doStop _heli;
    _heli flyInHeight 15;

    private _descentTimer = 0;
    waitUntil {
        sleep 0.5; _descentTimer = _descentTimer + 0.5;
        private _newH = (15 - _descentTimer) max 3;
        _heli flyInHeight _newH;
        _heli flyInHeightASL [_newH, _newH, _newH];
        (getPosATL _heli select 2) <= 5 || _descentTimer > 30 || !alive _heli
    };
    if (!alive _heli) exitWith { false };

    while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };
    _heli flyInHeight 0;
    _heli land "LAND";
    private _landTimeout = time + 30;
    waitUntil { sleep 0.5; !alive _heli || isTouchingGround _heli || time > _landTimeout };
    if (!isTouchingGround _heli && alive _heli) then {
        _heli setVelocity [0,0,0];
        _heli setPos [_targetPos # 0, _targetPos # 1, 0];
    };
    sleep 1;
    if (!alive _heli) exitWith { false };

    _heli setVehicleLock "UNLOCKED";
    _heli animateSource ["door_rear_source", 1];
    _heli animateDoor   ["door_rear_source", 1];
    ["STR_LL_Heli_Msg_Landed_Extract"] remoteExec ["LL_fnc_radioMessage", 0];

    private _task02bHostage   = missionNamespace getVariable ["LL_Task02b_Hostage", objNull];
    private _isTask02bExtract = !isNull _task02bHostage && { alive _task02bHostage } && { !(missionNamespace getVariable ["LL_Task02b_Freed_Done", false]) };

    private _task00Hostage    = missionNamespace getVariable ["LL_Task00_Hostage", objNull];
    private _isTask00Extract  = !isNull _task00Hostage && { alive _task00Hostage } && { missionNamespace getVariable ["LL_g_taskInProgress", false] };

    private _task06HVT        = missionNamespace getVariable ["LL_Task06_HVT", objNull];
    private _isTask06Extract  = !isNull _task06HVT && { alive _task06HVT } && { missionNamespace getVariable ["LL_g_taskInProgress", false] };

    private _ejectEH = -1;
    if (_isTask02bExtract || _isTask00Extract || _isTask06Extract) then {
        _ejectEH = _heli addEventHandler ["GetIn", {
            params ["_vehicle", "_role", "_unit"];
            private _h00 = missionNamespace getVariable ["LL_Task00_Hostage", objNull];
            private _h2b = missionNamespace getVariable ["LL_Task02b_Hostage", objNull];
            private _h06 = missionNamespace getVariable ["LL_Task06_HVT", objNull];

            if (_unit != _h00 && _unit != _h2b && _unit != _h06 && { group _unit != group driver _vehicle }) then {
                moveOut _unit;
                if (isPlayer _unit) then {
                    ["STR_LL_Heli_Msg_Extract_Players_Exit_Warning"] remoteExec ["LL_fnc_radioMessage", _unit];
                };
            };
        }];
    };

    private _timeout     = time + 600;
    private _shouldLeave = false;
    waitUntil {
        sleep 3;
        private _allHumans     = allPlayers select { alive _x };
        private _playersInHeli = { isPlayer _x && { alive _x } } count (crew _heli);

        if (_isTask02bExtract || _isTask00Extract || _isTask06Extract) then {

            private _hostage = objNull;
            if (_isTask02bExtract) then { _hostage = missionNamespace getVariable ["LL_Task02b_Hostage", objNull]; };
            if (_isTask00Extract) then { _hostage = missionNamespace getVariable ["LL_Task00_Hostage", objNull]; };
            if (_isTask06Extract) then { _hostage = missionNamespace getVariable ["LL_Task06_HVT", objNull]; };

            {
                if (_x != _hostage && { group _x != group driver _heli }) then {
                    moveOut _x;
                };
            } forEach (crew _heli);

            if (!isNull _hostage && { !alive _hostage }) then {
                _shouldLeave = true;
                "" remoteExec ["hintSilent", 0];
            };

            if (!isNull _hostage && { vehicle _hostage == _heli }) then { _shouldLeave = true; };

            if (time > _timeout) then { _shouldLeave = true; };

            if (!isNull _hostage && { vehicle _hostage != _heli }) then {
                (format [localize "STR_LL_Heli_Msg_Extract_Waiting_Hostage", round (_hostage distance2D _heli)])
                    remoteExec ["hintSilent", 0];
            } else {
                "" remoteExec ["hintSilent", 0];
            };
        } else {

            (format [localize "STR_LL_Heli_Msg_Extract_Counter", _playersInHeli, count _allHumans])
                remoteExec ["hintSilent", 0];
            if (_playersInHeli >= count _allHumans && { _playersInHeli > 0 }) then {
                _shouldLeave = true;
            };
            if (time > _timeout && { _playersInHeli == 0 }) then { _shouldLeave = true; };
        };

        !alive _heli || _shouldLeave || call _fnAborted
    };

    if (_ejectEH >= 0) then {
        _heli removeEventHandler ["GetIn", _ejectEH];
    };

    if (call _fnAborted) exitWith {
        "" remoteExec ["hintSilent", 0];
        false
    };

    if (!alive _heli) exitWith {
        "" remoteExec ["hintSilent", 0];
        false
    };

    _heli animateSource ["door_rear_source", 0];
    _heli animateDoor   ["door_rear_source", 0];
    _heli land "NONE";
    _heli setFuel 1;
    _heli engineOn true;
    sleep 3;
    _group setBehaviour "CARELESS";
    _group setCombatMode "RED";
    _group setSpeedMode  "FULL";
    ["STR_LL_Heli_Msg_Departing"] remoteExec ["LL_fnc_radioMessage", 0];

    private _boardedPlayers = crew _heli select { isPlayer _x && { alive _x } };

    if (count _boardedPlayers > 0) then {

        "" remoteExec ["hintSilent", 0];
        _heli flyInHeight _flyHeight;
        private _wpVic = _group addWaypoint [_homeBase, 0];
        _wpVic setWaypointType       "MOVE";
        _wpVic setWaypointBehaviour  "CARELESS";
        _wpVic setWaypointCombatMode "RED";
        _wpVic setWaypointSpeed      "FULL";
        _heli doMove _homeBase;
        _heli lock 2;
        sleep 25;
        if (alive _heli) then {
            ["MissionSuccess", true, true] remoteExec ["BIS_fnc_endMission", 0];
        };
        true
    } else {

        _heli flyInHeight _flyHeight;
        _heli doMove _homeBase;
        _heli lock 2; 

        private _hostage2b = missionNamespace getVariable ["LL_Task02b_Hostage", objNull];
        private _hostage00 = missionNamespace getVariable ["LL_Task00_Hostage", objNull];
        private _hvt06     = missionNamespace getVariable ["LL_Task06_HVT", objNull];
        {
            private _h = _x;
            if (!isNull _h) then {
                [_h] spawn {
                    params ["_unit"];
                    sleep 15;
                    if (!isNull _unit) then { deleteVehicle _unit; };
                };
            };
        } forEach [_hostage2b, _hostage00, _hvt06];

        false
    };
};

call _fnInitState;
missionNamespace setVariable ["LL_HELI_pending", [], false];  
diag_log "[LL][HELI_MGR] Gestionnaire initialisé — état IDLE.";

while { true } do {
    sleep 0.5;

    private _pending = missionNamespace getVariable ["LL_HELI_pending", []];
    if (count _pending > 0) then {

        _pending params ["_type", "_pos", "_caller", "_priority"];

        missionNamespace setVariable ["LL_HELI_pending", [], false];

        missionNamespace setVariable ["LL_HELI_type",     _type,     true];
        missionNamespace setVariable ["LL_HELI_priority", _priority, true];
        missionNamespace setVariable ["LL_HELI_caller",   _caller,   true];
        missionNamespace setVariable ["LL_HELI_abort",    false,     false];

        diag_log format ["[LL][HELI_MGR] Démarrage mission: type=%1 priorité=%2", _type, _priority];

        private _flyHeight      = 150;
        private _hoverHeight    = 15;
        private _loiterHeight   = 60;
        private _loiterRadius   = 250;
        private _loiterDuration = 180;

        if (count _pos < 3) then { _pos resize 3; };
        { if (isNil "_pos") exitWith {}; if (isNil { _pos # _forEachIndex }) then { _pos set [_forEachIndex, 0]; }; } forEach _pos;
        private _lzPos = [_caller, _type] call _fnGetLZ;
        if (_type == "CAS") then { _lzPos = if (count _pos >= 2 && { (_pos # 0) != 0 }) then { _pos } else { getPosATL _caller }; };

        private _spawnPos    = [_lzPos, _flyHeight] call _fnGetSpawnPos;
        private _homeBase    = +_spawnPos;
        private _spawnResult = [_spawnPos, _lzPos, _flyHeight] call _fnSpawnHeli;

        if (count _spawnResult == 0) then {
            private _errMsg = switch (_type) do {
                case "VEHICULE": { "STR_TAG_Msg_Vehicle_Error" };
                case "CAS":      { "STR_TAG_Msg_CAS_Error"     };
                default          { "STR_TAG_Msg_Ammo_Error"    };
            };
            [_errMsg] remoteExec ["LL_fnc_radioMessage", _caller];
            call _fnInitState;
        } else {
            _spawnResult params ["_heli", "_crew", "_group"];
            private _side = side _group;

            private _markerName = [_type, _lzPos] call _fnCreateMarker;

            private _aborted = [_heli, _group, _lzPos, _flyHeight] call _fnApproach;

            if (!alive _heli) then {

                deleteMarker _markerName; deleteMarker (_markerName + "_area");
                ["STR_LL_Heli_Msg_Killed"] remoteExec ["LL_fnc_radioMessage", 0];
                if (!isNull _group) then { deleteGroup _group; };
                call _fnInitState;
            } else {
                if (_aborted) then {

                    deleteMarker _markerName; deleteMarker (_markerName + "_area");
                    [_heli, _group, _crew, _homeBase, _flyHeight, false, false] call _fnRTB;
                    call _fnInitState;
                } else {

                    private _victoryTriggered  = false;
                    private _deadDuringMission = false;

                    switch (_type) do {

                        case "CAS": {
                            private _casAborted = [
                                _heli, _group, _caller, _lzPos,
                                _loiterHeight, _loiterRadius, _loiterDuration
                            ] call _fnExecCAS;

                            deleteMarker _markerName; deleteMarker (_markerName + "_area");

                            if (!alive _heli) then {
                                _deadDuringMission = true;
                            } else {
                                if (!_casAborted) then {
                                    ["STR_TAG_Msg_CAS_RTB"] remoteExec ["LL_fnc_radioMessage", _caller];
                                };

                                [_heli, _group, _crew, _homeBase, _flyHeight, false, !_casAborted] call _fnRTB;
                            };
                        };

                        case "LIVRAISON";
                        case "VEHICULE": {
                            private _needCargoRTB = [
                                _heli, _group, _crew, _caller, _type,
                                _lzPos, _hoverHeight, _side
                            ] call _fnExecDelivery;

                            deleteMarker _markerName; deleteMarker (_markerName + "_area");

                            if (!alive _heli) then {
                                _deadDuringMission = true;
                            } else {
                                [_heli, _group, _crew, _homeBase, _flyHeight, _needCargoRTB, false] call _fnRTB;
                            };
                        };

                        case "DEBARQUEMENT": {
                            [_heli, _group, _crew, _caller, _lzPos, _homeBase, _side] call _fnExecDeploy;
                            deleteMarker _markerName; deleteMarker (_markerName + "_area");

                            if (!alive _heli) then {
                                _deadDuringMission = true;
                            } else {
                                [_heli, _group, _crew, _homeBase, _flyHeight, false, false] call _fnRTB;
                            };
                        };

                        case "EMBARQUEMENT": {
                            private _extractResult = [
                                _heli, _group, _crew, _caller,
                                _lzPos, _homeBase, _flyHeight
                            ] call _fnExecExtract;
                            _victoryTriggered = _extractResult;

                            deleteMarker _markerName; deleteMarker (_markerName + "_area");

                            if (!alive _heli) then {
                                _deadDuringMission = true;
                            } else {
                                if (!_victoryTriggered) then {
                                    [_heli, _group, _crew, _homeBase, _flyHeight, false, false] call _fnRTB;
                                };
                            };
                        };
                    };

                    if (_deadDuringMission) then {
                        ["STR_LL_Heli_Msg_Killed"] remoteExec ["LL_fnc_radioMessage", 0];
                        if (!isNull _group) then { deleteGroup _group; };
                    };

                    if (!_victoryTriggered) then { call _fnInitState; };
                    diag_log format ["[LL][HELI_MGR] Mission %1 terminée.", _type];
                };
            };
        };
    };
};
