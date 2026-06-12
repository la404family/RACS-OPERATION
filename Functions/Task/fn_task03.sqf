params [["_mode", "init", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {};

if (_mode == "init") exitWith {
    private _allHeliports = (allMissionObjects "Logic") select { (vehicleVarName _x) select [0, 9] == "Heliport_" };
    if (count _allHeliports < 1) exitWith {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then { diag_log "[LL] task03 ERROR: Pas de Heliport_ trouvé."; };
        missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    };

    private _targetNumRadios = 1 + floor (random 4); 
    private _selectedRadios = [];
    private _logicsPool = _allHeliports call BIS_fnc_arrayShuffle;
    private _alivePlayers = allPlayers select { alive _x };

    {
        private _candidate = _x;
        private _candidatePos = getPosASL _candidate;
        private _valid = true;

        { if (_x distance2D _candidatePos < 250) exitWith { _valid = false; }; } forEach _alivePlayers;

        if (_valid) then {
            { if ((getPosASL _x) distance2D _candidatePos < 100) exitWith { _valid = false; }; } forEach _selectedRadios;
        };

        if (_valid) then { _selectedRadios pushBack _candidate; };
        if (count _selectedRadios >= _targetNumRadios) exitWith {};
    } forEach _logicsPool;

    private _numRadios = count _selectedRadios;
    if (_numRadios < 1) exitWith {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then { diag_log "[LL] task03 ERROR: Impossible de trouver des emplacements valides à >250m. Relance dans 15s."; };
        [[], "LL_fnc_task03"] spawn { sleep 15; ["init"] spawn LL_fnc_task03; };
    };

    missionNamespace setVariable ["LL_Task03_AllUnits", [], true];
    missionNamespace setVariable ["LL_Task03_Destroyed", 0, true];
    missionNamespace setVariable ["LL_Task03_Total", _numRadios, true];
    
    private _allUnits = [];
    private _radios = [];

    for "_i" from 0 to (_numRadios - 1) do {
        private _logic = _selectedRadios select _i;
        private _spawnPos = getPosASL _logic;
        _spawnPos set [2, (_spawnPos select 2) + 0.2];

        private _grp = createGroup [east, true];
        _grp setBehaviour "AWARE";
        _grp setCombatMode "RED";
        private _numGuards = 4 + floor (random 5);
        for "_g" from 1 to _numGuards do {
            sleep 0.7;
            private _guardClass = selectRandom ["CUP_O_TK_Soldier", "CUP_O_TK_Soldier_GL", "CUP_O_TK_Soldier_AR"];
            private _guard = _grp createUnit [_guardClass, _spawnPos, [], 0, "NONE"];
            _guard setPosASL _spawnPos;
            _guard allowDamage false;
            [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };
            _allUnits pushBack _guard;

            private _patrolPos = _spawnPos getPos [4 + random 21, random 360];
            _guard doMove _patrolPos;
        };

        private _mkrName = format ["mkr_task03_zone_%1", _i];
        createMarker [_mkrName, _spawnPos getPos [random 50, random 360]];
        _mkrName setMarkerType "hd_unknown";
        _mkrName setMarkerColor "ColorOrange";
        _mkrName setMarkerText format ["%1 %2", localize "STR_LL_Task_03_Marker", _i + 1];

        sleep 0.7;

        private _radioClass = selectRandom ["RuggedTerminal_01_communications_hub_F", "RuggedTerminal_01_communications_F"];
        private _radio = createVehicle [_radioClass, [0,0,0], [], 0, "CAN_COLLIDE"];
        _radio setPosASL _spawnPos;
        _radio setDir (random 360);
        _radio setVariable ["LL_Task_Status", "WAIT", true];
        _radio setVariable ["LL_Radio_Marker", _mkrName, true];

        _radio allowDamage false;
        [_radio] spawn { sleep 3; (_this select 0) allowDamage true; };

        _radios pushBack _radio;

        [_radio] remoteExec ["LL_fnc_task03_addAction", 0, true];
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
    
    // Alerte le joueur
    ["STR_LL_Task_03_Warning"] remoteExec ["LL_fnc_radioMessage", 0];

    // Création de l'explosif visuel
    private _charge = createVehicle ["DemoCharge_F", getPosASL _radio, [], 0, "CAN_COLLIDE"];
    _charge attachTo [_radio, [0, 0, 0.2]]; 
    _charge setVectorUp [0, 0, 1];

    [_radio, _charge] spawn {
        params ["_radio", "_charge"];
        
        sleep 40; // Compte à rebours de 40s
        
        if (!isNull _charge) then { deleteVehicle _charge; };
        
        private _pos = getPos _radio;
        private _mkrName = _radio getVariable ["LL_Radio_Marker", ""];
        
        // Explosion
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
            
            // Nettoyage des marqueurs après 10s
            [] spawn {
                sleep 10;
                private _radios = missionNamespace getVariable ["LL_Task03_Radios", []];
                for "_i" from 0 to ((count _radios) - 1) do { deleteMarker format ["mkr_task03_zone_%1", _i]; };
            };
            
            // Dissolution hors de vue - TASK_RULES §14
            private _allUnits = missionNamespace getVariable ["LL_Task03_AllUnits", []];
            private _guards = _allUnits select { alive _x };
            
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

                        if (count _dissolvePos == 0) then { _dissolvePos = _refPos getPos [400, random 360]; };

                        while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                        private _wp = _grp addWaypoint [_dissolvePos, 5];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointSpeed "FULL";
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
        };
    };
};
