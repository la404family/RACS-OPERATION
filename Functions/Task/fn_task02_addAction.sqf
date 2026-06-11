/*
    LL_fnc_task02_addAction
    Client uniquement.
*/
params ["_bomb"];

if (!hasInterface) exitWith {};

_bomb addAction [
    format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_02_Action"],
    {
        params ["_target", "_caller", "_actionId", "_arguments"];
        _target removeAction _actionId;
        ["defuse", [_target, _caller]] remoteExec ["LL_fnc_task02", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "alive _target && _this distance _target < 4 && (_target getVariable ['LL_Bomb_Status', 'WAIT']) == 'WAIT'"
];
