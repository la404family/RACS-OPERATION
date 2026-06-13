if (!hasInterface) exitWith {};

_this spawn {
    params [["_truck", objNull, [objNull]]];

    private _timeout = time + 15;
    waitUntil { !isNull _truck || time > _timeout };

    if (isNull _truck) exitWith {};

    _truck addAction [
        format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_04_Action"],
        {
            params ["_target", "_caller", "_actionId"];
            if (_target getVariable ["LL_Task04_Triggered", false]) exitWith {};
            _target setVariable ["LL_Task04_Triggered", true, true];

            removeAllActions _target;
            _caller playActionNow "PutDown";

            ["extract", [_target, _caller]] remoteExec ["LL_fnc_task04", 2];
        },
        nil, 6.0, true, true, "", "alive _target && _this distance _target < 15"
    ];
};
