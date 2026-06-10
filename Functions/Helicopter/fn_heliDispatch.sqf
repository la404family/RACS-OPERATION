if (!isServer) exitWith {};

params [
    ["_type",     "CAS",   [""]],
    ["_pos",      [0,0,0], [[]]],
    ["_caller",   objNull, [objNull]],
    ["_priority", 1,       [0]]
];

if (_type == "CAS" && { time < (missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0]) }) exitWith {
    private _rem = ceil ((missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0]) - time);
    ["STR_LL_Heli_Dispatch_Cooldown", [_rem]] remoteExec ["LL_fnc_radioMessage", _caller];
    diag_log format ["[LL][DISPATCH] CAS refusé — cooldown %1s.", _rem];
};

if (_type == "VEHICULE" && { missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false] }) exitWith {
    ["STR_LL_Heli_Dispatch_VehicleAlready"] remoteExec ["LL_fnc_radioMessage", _caller];
    diag_log "[LL][DISPATCH] VEHICULE refusé — déjà livré (usage unique).";
};

private _state   = missionNamespace getVariable ["LL_HELI_state",    "IDLE"];
private _curPrio = missionNamespace getVariable ["LL_HELI_priority", 0];
private _curType = missionNamespace getVariable ["LL_HELI_type",     ""];

private _interruptibleStates = ["APPROACHING", "CAS", "DELIVERING", "DEPLOYING", "RTB", "RTB_WITH_CARGO"];

private _typePriority = switch (_type) do {
    case "EMBARQUEMENT": { 2 };
    default              { 1 };
};

if (_priority < _typePriority) then { _priority = _typePriority; };

switch (true) do {

    case (_state == "IDLE"): {
        private _approveMsgKey = switch (_type) do {
            case "LIVRAISON":    { "STR_LL_Heli_Dispatch_Approve_LIVRAISON" };
            case "VEHICULE":     { "STR_LL_Heli_Dispatch_Approve_VEHICULE" };
            case "CAS":          { "STR_LL_Heli_Dispatch_Approve_CAS" };
            case "DEBARQUEMENT": { "STR_LL_Heli_Dispatch_Approve_DEBARQUEMENT" };
            case "EMBARQUEMENT": { "STR_LL_Heli_Dispatch_Approve_EMBARQUEMENT" };
            default              { "STR_LL_Heli_Dispatch_Approve_DEFAULT" };
        };
        [_approveMsgKey] remoteExec ["LL_fnc_radioMessage", _caller];

        if (_type == "VEHICULE") then {
            missionNamespace setVariable ["TAG_VehicleSupport_Delivered", true, true];
        };

        missionNamespace setVariable ["LL_HELI_pending", [_type, _pos, _caller, _priority], false];
        diag_log format ["[LL][DISPATCH] Accepté: type=%1 prio=%2", _type, _priority];
    };

    case (_priority > _curPrio && { _state in _interruptibleStates }): {
        private _abortMsgKey = switch (_curType) do {
            case "CAS":          { "STR_LL_Heli_Dispatch_Abort_CAS" };
            case "LIVRAISON":    { "STR_LL_Heli_Dispatch_Abort_LIVRAISON" };
            case "VEHICULE":     { "STR_LL_Heli_Dispatch_Abort_VEHICULE" };
            case "DEBARQUEMENT": { "STR_LL_Heli_Dispatch_Abort_DEBARQUEMENT" };
            default              { "STR_LL_Heli_Dispatch_Abort_DEFAULT" };
        };
        [_abortMsgKey] remoteExec ["LL_fnc_radioMessage", 0];

        private _newMsgKey = switch (_type) do {
            case "EMBARQUEMENT": { "STR_LL_Heli_Dispatch_New_EMBARQUEMENT" };
            default              { "STR_LL_Heli_Dispatch_New_DEFAULT" };
        };
        [_newMsgKey] remoteExec ["LL_fnc_radioMessage", _caller];

        missionNamespace setVariable ["LL_HELI_abort",   true,                              false];
        missionNamespace setVariable ["LL_HELI_pending", [_type, _pos, _caller, _priority], false];
        diag_log format ["[LL][DISPATCH] Interruption: %1→%2 prio(%3>%4) état=%5",
            _curType, _type, _priority, _curPrio, _state];
    };

    default {
        private _denyMsgKey = switch (true) do {
            case (_type == "EMBARQUEMENT" && _curType == "EMBARQUEMENT"): { "STR_LL_Heli_Dispatch_Deny_EMBARQUEMENT" };
            case (_type == "CAS"): { "STR_LL_Heli_Dispatch_Deny_CAS" };
            case (_type == "LIVRAISON"): { "STR_LL_Heli_Dispatch_Deny_LIVRAISON" };
            case (_type == "VEHICULE"): { "STR_LL_Heli_Dispatch_Deny_VEHICULE" };
            case (_type == "DEBARQUEMENT"): { "STR_LL_Heli_Dispatch_Deny_DEBARQUEMENT" };
            default { "STR_LL_Heli_Dispatch_Deny_DEFAULT" };
        };
        if (_type == "EMBARQUEMENT" && _curType == "EMBARQUEMENT") then {
            [_denyMsgKey] remoteExec ["LL_fnc_radioMessage", _caller];
        } else {
            [_denyMsgKey, [_curType]] remoteExec ["LL_fnc_radioMessage", _caller];
        };
        diag_log format ["[LL][DISPATCH] Refusé: type=%1 état=%2 prio demandé=%3 prio courante=%4",
            _type, _state, _priority, _curPrio];
    };
};
