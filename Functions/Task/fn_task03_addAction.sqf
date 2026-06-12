if (!hasInterface) exitWith {};

params ["_radio"];

_radio addAction [
    format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_03_Action"],
    {
        params ["_target", "_caller", "_actionId", "_arguments"];
        if (missionNamespace getVariable ["LL_Task03_Triggered_" + (_target call BIS_fnc_netId), false]) exitWith {};
        missionNamespace setVariable ["LL_Task03_Triggered_" + (_target call BIS_fnc_netId), true, true];
        
        _target removeAction _actionId;
        
        ["plant", [_target, _caller]] remoteExec ["LL_fnc_task03", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "alive _target && _this distance _target < 4 && (_target getVariable ['LL_Task_Status', 'WAIT'] == 'WAIT')"
];
