if (!isServer) exitWith {};

params [
    ["_caller", objNull, [objNull]],
    ["_targetPos", [0,0,0], [[]]]
];

if (isNull _caller) exitWith {};
if (missionNamespace getVariable ["LL_Drone_Active", false]) exitWith {
    [localize "STR_Drone_AlreadyActive"] remoteExec ["systemChat", owner _caller];
};

LL_Drone_Active = true;
publicVariable "LL_Drone_Active";

private _altitude = 350;
private _orbitRadius = 400;
private _scanRadius = 500;
private _duration = 300;
private _spawnPos = [_targetPos select 0, (_targetPos select 1) - 2000, _altitude];

private _grp = createGroup independent;
private _drone = createVehicle ["CUP_B_USMC_DYN_MQ9", _spawnPos, [], 0, "FLY"];
_drone setDir (_spawnPos getDir _targetPos);
_drone setVelocityModelSpace [0, 80, 0];
createVehicleCrew _drone;
(crew _drone) joinSilent _grp;

_drone allowDamage false;

_grp setCombatMode "RED";
_grp setBehaviour "COMBAT";
{
    _x allowDamage false;
    _x disableAI "SUPPRESSION";
} forEach units _grp;

_grp addEventHandler ["EnemyDetected", {
    params ["_grp", "_detected"];
    if (_detected isKindOf "Man") then {
        { _x forgetTarget _detected } forEach units _grp;
    };
}];

private _markerArea = createMarker ["LL_Drone_Area", _targetPos];
_markerArea setMarkerShape "ELLIPSE";
_markerArea setMarkerSize [_orbitRadius, _orbitRadius];
_markerArea setMarkerColor "ColorBlue";
_markerArea setMarkerAlpha 0.15;
_markerArea setMarkerBrush "SolidBorder";

private _markerIcon = createMarker ["LL_Drone_Icon", _targetPos];
_markerIcon setMarkerType "b_air";
_markerIcon setMarkerColor "ColorBlue";
_markerIcon setMarkerSize [1.2, 1.2];
_markerIcon setMarkerText "  MQ-9 Reaper";

private _markerDrone = createMarker ["LL_Drone_Pos", getPosATL _drone];
_markerDrone setMarkerType "mil_triangle";
_markerDrone setMarkerColor "ColorCIV";
_markerDrone setMarkerSize [0.9, 0.9];

[format [localize "STR_Drone_Approach", round (_duration / 60)]] remoteExec ["systemChat", 0];

[_drone, _targetPos, _orbitRadius, _scanRadius, _duration, _markerArea, _markerIcon, _markerDrone, _grp] spawn {
    params ["_drone", "_center", "_radius", "_scanR", "_dur", "_mArea", "_mIcon", "_mDrone", "_grp"];

    private _wp = _grp addWaypoint [_center, 0];
    _wp setWaypointType "LOITER";
    _wp setWaypointLoiterRadius _radius;
    _wp setWaypointLoiterType "CIRCLE";
    _wp setWaypointSpeed "LIMITED";

    private _endTime = time + _dur;
    private _enemyMarkers = createHashMap;

    while { time < _endTime && alive _drone } do {
        _mDrone setMarkerPos (getPosATL _drone);

        private _enemies = _center nearEntities [["CAManBase", "Car", "Tank", "Helicopter", "Plane", "Ship"], _scanR];
        _enemies = _enemies select { alive _x && side _x == east };

        private _currentEnemyIds = [];

        {
            private _id = str (netId _x);
            _currentEnemyIds pushBack _id;
            private _mName = format ["LL_Drone_Enemy_%1", _id];

            if !(_id in keys _enemyMarkers) then {
                createMarker [_mName, getPosATL _x];
                _mName setMarkerType "mil_dot";
                _mName setMarkerColor "ColorRed";
                _mName setMarkerSize [0.7, 0.7];
                _enemyMarkers set [_id, _mName];
            };

            _mName setMarkerPos (getPosATL _x);
        } forEach _enemies;

        private _toRemove = [];
        {
            private _eid = _x;
            private _mkr = _y;
            if !(_eid in _currentEnemyIds) then {
                deleteMarker _mkr;
                _toRemove pushBack _eid;
            };
        } forEach _enemyMarkers;
        { _enemyMarkers deleteAt _x; } forEach _toRemove;

        private _vehicles = _enemies select { !(_x isKindOf "CAManBase") };
        {
            _grp reveal [_x, 4];
            (gunner _drone) doTarget _x;
            (gunner _drone) doFire _x;
        } forEach _vehicles;

        sleep 3;
    };

    [localize "STR_Drone_RTB"] remoteExec ["systemChat", 0];

    { deleteMarker _y; } forEach _enemyMarkers;
    _enemyMarkers = createHashMap;
    deleteMarker _mArea;
    deleteMarker _mIcon;
    deleteMarker _mDrone;

    if (alive _drone) then {
        private _rtbPos = [
            (_center select 0),
            (_center select 1) - 3000,
            350
        ];
        private _wpRtb = _grp addWaypoint [_rtbPos, 0];
        _wpRtb setWaypointType "MOVE";
        _wpRtb setWaypointSpeed "FULL";
        sleep 60;
        { deleteVehicle _x; } forEach (crew _drone);
        deleteVehicle _drone;
    };

    deleteGroup _grp;

    sleep 120;
    LL_Drone_Active = false;
    publicVariable "LL_Drone_Active";
    [localize "STR_Drone_Available"] remoteExec ["systemChat", 0];
};
