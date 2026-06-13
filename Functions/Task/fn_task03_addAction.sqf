if (!hasInterface) exitWith {};

_this spawn {
    params [["_radio", objNull, [objNull]]];

    private _timeout = time + 15;
    waitUntil { !isNull _radio || time > _timeout };

    if (isNull _radio) exitWith {};

    _radio addAction [
        format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_03_Action"],
        {
            params ["_target", "_caller", "_actionId", "_arguments"];
            if (_target getVariable ["LL_Task03_Triggered", false]) exitWith {};
            _target setVariable ["LL_Task03_Triggered", true, true];

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
};
