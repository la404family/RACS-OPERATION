/*
    LL_fnc_task01
    Serveur uniquement.
    Task 01 : Assassinat et récupération de documents.
*/
params [["_mode", "init", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {};

if (missionNamespace getVariable ["DEBUG_MODE", true]) then {
    diag_log format ["[LL] task01: appel avec mode = %1", _mode];
};

if (_mode == "init") exitWith {
    // 1. Trouver les logiques de spawn M_Dans_Bat_
    private _allLogics = (allMissionObjects "Logic") select { (vehicleVarName _x) select [0, 11] == "M_Dans_Bat_" };
    if (count _allLogics == 0) exitWith {
        diag_log "[LL] task01 ERROR: Aucun M_Dans_Bat_ trouvé sur la carte.";
    };

    // 2. Sélectionner 2 à 4 lieux aléatoires
    private _numSpawns = (2 + floor (random 3)) min (count _allLogics);
    private _selectedLogics = [];
    private _logicsPool = +_allLogics;
    
    for "_i" from 1 to _numSpawns do {
        private _logic = selectRandom _logicsPool;
        _logicsPool = _logicsPool - [_logic];
        _selectedLogics pushBack _logic;
    };

    // 3. Choix de la cible possédant les documents
    private _targetIndex = floor random _numSpawns;

    // Tableaux de suivi
    missionNamespace setVariable ["LL_Task01_AllUnits", [], true];

    // 4. Boucle de spawn
    for "_i" from 0 to (_numSpawns - 1) do {
        private _logic = _selectedLogics select _i;
        private _spawnPos = getPosASL _logic;
        _spawnPos set [2, (_spawnPos select 2) + 0.2];

        private _grp = createGroup [east, true];
        _grp setBehaviour "SAFE";
        _grp setCombatMode "RED";

        // Gardes (3 à 5)
        private _numGuards = 3 + floor (random 3);
        private _guards = [];
        for "_g" from 1 to _numGuards do {
            sleep 0.7;
            private _guardClass = selectRandom ["CUP_O_TK_Soldier", "CUP_O_TK_Soldier_GL", "CUP_O_TK_Soldier_AR"];
            private _guard = _grp createUnit [_guardClass, _spawnPos, [], 0, "NONE"];
            _guard setPosASL _spawnPos;
            _guard allowDamage false;
            [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };
            _guards pushBack _guard;
            
            // Patrouille locale
            private _patrolPos = _spawnPos getPos [random 25, random 360];
            _guard doMove _patrolPos;
            _guard setSpeedMode "LIMITED";
        };

        // Officier (en dernier)
        sleep 0.7;
        private _officer = _grp createUnit ["CUP_O_TK_Officer", _spawnPos, [], 0, "NONE"];
        _officer setPosASL _spawnPos;
        _officer allowDamage false;
        [_officer] spawn { sleep 3; (_this select 0) allowDamage true; };
        _officer setRank "COLONEL";

        // Marqueurs carte
        private _mkrName = format ["mkr_task01_target_%1", _i];
        createMarker [_mkrName, _spawnPos];
        _mkrName setMarkerType "mil_destroy";
        _mkrName setMarkerColor "ColorRed";
        _mkrName setMarkerText format ["%1 %2", localize "STR_LL_Task_01_Marker", _i + 1];

        // Mémorisation
        private _allUnits = missionNamespace getVariable ["LL_Task01_AllUnits", []];
        _allUnits append _guards;
        _allUnits pushBack _officer;
        missionNamespace setVariable ["LL_Task01_AllUnits", _allUnits, true];

        // Est-ce la cible ?
        if (_i == _targetIndex) then {
            _officer setVariable ["LL_hasDocuments", true, true];
        } else {
            _officer setVariable ["LL_hasDocuments", false, true];
        };

        // Event handler de mort pour l'officier
        _officer addEventHandler ["Killed", {
            params ["_unit", "_killer", "_instigator", "_useEffects"];
            
            // Si c'est le porteur de documents
            if (_unit getVariable ["LL_hasDocuments", false]) then {
                private _pos = getPosATL _unit; // On utilise ATL pour les objets au sol
                _pos set [2, (_pos select 2) + 0.05];
                
                private _doc = createVehicle ["SecretDocuments_01_F", _pos, [], 0, "CAN_COLLIDE"];
                _doc setPosATL _pos;
                
                // Mettre à jour la tâche
                ["task_01_assassinat", _pos] call BIS_fnc_taskSetDestination;

                // Marqueur visuel
                private _mkrDoc = createMarker ["mkr_task01_doc", _pos];
                _mkrDoc setMarkerType "mil_objective";
                _mkrDoc setMarkerColor "ColorWhite";
                _mkrDoc setMarkerText (localize "STR_LL_Task_01_MarkerDoc");

                // Ajouter l'action au cadavre (pour tous les clients)
                [_unit, _doc] remoteExec ["LL_fnc_task01_addAction", 0, true];
            };
        }];
    };

    // 5. Création de la tâche Arma 3
    [
        independent,
        ["task_01_assassinat"],
        [
            localize "STR_LL_Task_01_Desc",
            localize "STR_LL_Task_01_Title",
            localize "STR_LL_Task_01_Marker"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "kill",
        false
    ] call BIS_fnc_taskCreate;
    
    // Notification générique (Radio + Texte)
    ["STR_LL_Task_Assigned"] remoteExec ["LL_fnc_radioMessage", 0];
};

if (_mode == "collect") exitWith {
    _args params ["_corpse", "_doc"];

    if (missionNamespace getVariable ["LL_Task01_Completed", false]) exitWith {};
    missionNamespace setVariable ["LL_Task01_Completed", true, true];

    // Supprimer le document
    if (!isNull _doc) then { deleteVehicle _doc; };

    // Fin de tâche
    ["task_01_assassinat", "SUCCEEDED", true] call BIS_fnc_taskSetState;
    deleteMarker "mkr_task01_doc";
    
    // Nettoyer les marqueurs de cible
    for "_i" from 0 to 3 do {
        deleteMarker format ["mkr_task01_target_%1", _i];
    };

    // Dissolution des IA restantes (TASK_RULES §14)
    private _allUnits = missionNamespace getVariable ["LL_Task01_AllUnits", []];
    private _dissolveGrp = createGroup [east, true];
    private _alive = _allUnits select { alive _x };
    
    if (count _alive > 0) then {
        {
            _x enableAI "MOVE";
            _x setBehaviour "SAFE";
            _x setSpeedMode "FULL";
        } forEach _alive;
        
        _alive joinSilent _dissolveGrp;

        [_alive, _dissolveGrp] spawn {
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
