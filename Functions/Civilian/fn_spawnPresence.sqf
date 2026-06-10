if (!isServer) exitWith {};

private _SPAWN_DIST = 500;
private _MIN_DIST = 50;
private _CLEANUP_DIST = 1200;
private _MAX_CIVILS = 55;
private _PATROL_DIST = 200;
private _SLEEP = 10;

if (isNil "LL_s_civSpawned") then { LL_s_civSpawned = []; };

while { true } do {
    sleep _SLEEP;

    {
        private _civ = _x;
        if (isNull _civ || !alive _civ) then {
            LL_s_civSpawned = LL_s_civSpawned - [_civ];
        } else {
            private _tooFar = true;
            {
                if (isPlayer _x && { (_x distance2D _civ) < _CLEANUP_DIST }) exitWith {
                    _tooFar = false;
                };
            } forEach allPlayers;

            if (_tooFar) then {
                private _grp = group _civ;
                deleteVehicle _civ;
                LL_s_civSpawned = LL_s_civSpawned - [_civ];
                if (count (units _grp) == 0) then { deleteGroup _grp; };
            };
        };
    } forEach (+ LL_s_civSpawned);

    LL_s_civSpawned = LL_s_civSpawned select { !isNull _x && alive _x };

    if (count LL_s_civSpawned < _MAX_CIVILS) then {
        private _players = allPlayers select { alive _x };
        if (count _players == 0) then { continue };

        private _refPlayer = selectRandom _players;
        private _refPos = getPosATL _refPlayer;

        private _buildings = nearestObjects [_refPos, ["House","Building"], _SPAWN_DIST];
        _buildings = _buildings select { (_x distance2D _refPlayer) > _MIN_DIST };
        if (count _buildings == 0) then { continue };

        private _building = selectRandom _buildings;
        private _bPosList = _building buildingPos -1;
        if (count _bPosList == 0) then { continue };

        private _bPos = selectRandom _bPosList;
        _bPos set [2, (_bPos select 2) + 0.5];

        private _class = "C_man_1";
        private _template = [];
        if (!isNil "MISSION_CivilianTemplates" && { count MISSION_CivilianTemplates > 0 }) then {
            _template = selectRandom MISSION_CivilianTemplates;
            _class = _template select 0;
        };

        private _grp = createGroup civilian;
        private _civ = _grp createUnit [_class, _bPos, [], 0, "NONE"];
        _civ setPosASL (AGLToASL _bPos);

        [_civ, _template] call LL_fnc_applyTemplate;

        [_grp, getPosATL _civ, _PATROL_DIST] call BIS_fnc_taskPatrol;

        LL_s_civSpawned pushBack _civ;
    };
};
