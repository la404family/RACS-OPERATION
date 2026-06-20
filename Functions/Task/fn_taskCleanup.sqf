params [["_units", [], [[]]]];

if (!isServer) exitWith {};

private _alivePlayers = allPlayers select { alive _x };
if (count _alivePlayers == 0) exitWith {
    {
        if (!isNull _x) then {
            if (_x isKindOf "LandVehicle" || _x isKindOf "Air" || _x isKindOf "Ship") then {
                { deleteVehicle _x; } forEach (crew _x);
            };
            deleteVehicle _x;
        };
    } forEach _units;
};

private _itemsToDelete = [];
private _closeUnits = [];

{
    private _item = _x;
    if (!isNull _item) then {
        private _far = true;
        {
            if (_x distance2D _item <= 1500) exitWith { _far = false; };
        } forEach _alivePlayers;

        if (_far) then {
            _itemsToDelete pushBack _item;
        } else {
            if (_item isKindOf "Man") then {
                if (alive _item) then { _closeUnits pushBack _item; };
            } else {
                if (count crew _item == 0) then {
                    _itemsToDelete pushBack _item;
                };
            };
        };
    };
} forEach _units;

{
    if (!isNull _x) then {
        if (_x isKindOf "LandVehicle" || _x isKindOf "Air" || _x isKindOf "Ship") then {
            { deleteVehicle _x; } forEach (crew _x);
        };
        deleteVehicle _x;
    };
} forEach _itemsToDelete;

private _enemyUnits = _closeUnits select { side _x == east };
if (count _enemyUnits > 0) then {
    private _groups = [];
    private _curGrp = grpNull;
    {
        if (isNull _curGrp || { count units _curGrp >= 3 }) then {
            _curGrp = createGroup [east, true];
            _groups pushBack _curGrp;
        };
        [_x] joinSilent _curGrp;
    } forEach _enemyUnits;

    {
        private _grp = _x;
        _grp setBehaviour "COMBAT";
        _grp setCombatMode "RED";
        _grp setSpeedMode "FULL";

        {
            _x enableAI "MOVE";
            _x enableAI "AUTOTARGET";
            _x enableAI "TARGET";
            _x enableAI "WEAPONAIM";
            _x setUnitPos "UP";
            _x setBehaviour "COMBAT";
            _x setSpeedMode "FULL";
            _x disableAI "SUPPRESSION";
            _x setSkill ["courage", 1.0];
            _x setSkill ["aimingAccuracy", 0.15 + random 0.15];
        } forEach (units _grp);
    } forEach _groups;

    [_groups] spawn {
        params ["_groups"];
        while { count _groups > 0 } do {
            sleep 10;
            private _alivePlayers = allPlayers select { alive _x };
            if (count _alivePlayers == 0) exitWith {};

            _groups = _groups select { !isNull _x && { ({ alive _x } count units _x) > 0 } };

            {
                private _grp = _x;
                private _leader = leader _grp;
                if (!isNull _leader && alive _leader) then {
                    private _closestPlayer = objNull;
                    private _minDist = 999999;
                    {
                        private _d = _leader distance2D _x;
                        if (_d < _minDist) then {
                            _minDist = _d;
                            _closestPlayer = _x;
                        };
                    } forEach _alivePlayers;

                    if (!isNull _closestPlayer) then {
                        { _x reveal [_closestPlayer, 4]; } forEach (units _grp);

                        while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                        private _wp = _grp addWaypoint [getPosATL _closestPlayer, 10];
                        _wp setWaypointType "SAD";
                        _wp setWaypointSpeed "FULL";
                        _wp setWaypointBehaviour "COMBAT";
                        _wp setWaypointCombatMode "RED";
                    };
                };
            } forEach _groups;
        };
    };
};

private _fleeingUnits = _closeUnits select { side _x != east };
if (count _fleeingUnits > 0) then {
    private _side = side (_fleeingUnits select 0);
    private _dissolveGrp = createGroup [_side, true];
    {
        _x enableAI "MOVE";
        _x setBehaviour "SAFE";
        _x setSpeedMode "FULL";
        _x setVariable ["LL_TaskXX_Escaping", true, true];
    } forEach _fleeingUnits;
    _fleeingUnits joinSilent _dissolveGrp;

    [_fleeingUnits, _dissolveGrp] spawn {
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
