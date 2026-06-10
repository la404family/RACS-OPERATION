if (!isServer) exitWith {};

params [
    ["_supportType",  "CAS",   [""]],
    ["_targetPos",    [0,0,0], [[]]],
    ["_caller",       objNull, [objNull]],
    ["_actionTarget", objNull, [objNull]],
    ["_actionId",     -1,      [0]]
];

if (_supportType == "VEHICULE") then {
    if (!(missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false])
        && { _actionId != -1 } && { !isNull _actionTarget }) then {
        [_actionTarget, _actionId] remoteExec ["removeAction", 0, true];
    };
};

private _priority = switch (_supportType) do {
    case "EMBARQUEMENT": { 2 };
    default              { 1 };
};

[_supportType, _targetPos, _caller, _priority] call LL_fnc_heliDispatch;
