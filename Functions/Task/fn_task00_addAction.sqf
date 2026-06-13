if (!hasInterface) exitWith {};

_this spawn {
    params [["_hostage", objNull, [objNull]]];

    private _timeout = time + 15;
    waitUntil { !isNull _hostage || time > _timeout };

    if (isNull _hostage) exitWith {};

    _hostage addAction [
        format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_00_Action"],
        {
            params ["_target", "_caller", "_actionId"];

            if (missionNamespace getVariable ["LL_Task00_Triggered", false]) exitWith {};
            missionNamespace setVariable ["LL_Task00_Triggered", true, true];

            _target removeAction _actionId;

            ["free", [_target, _caller]] remoteExec ["LL_fnc_task00", 2];
        },
        nil, 6.0, true, true, "", "alive _target && _this distance _target < 4"
    ];
};
