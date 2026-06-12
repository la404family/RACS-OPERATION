if (!hasInterface) exitWith {};

[] spawn {
    waitUntil { sleep 0.5; !isNull (missionNamespace getVariable ["LL_Task04_HVT", objNull]) };
    private _hvt = missionNamespace getVariable ["LL_Task04_HVT", objNull];

    private _actionText = localize "STR_LL_Task_04_Action";
    if (_actionText == "") then { _actionText = "Menotter et Capturer"; };

    _hvt addAction [
        format ["<t color='#FFFF00'>%1</t>", _actionText],
        {
            params ["_target", "_caller", "_actionId"];

            if (missionNamespace getVariable ["LL_Task04_Triggered", false]) exitWith {};
            missionNamespace setVariable ["LL_Task04_Triggered", true, true];

            _target removeAction _actionId;
            _caller playActionNow "PutDown";

            ["capture", [_target, _caller]] remoteExec ["LL_fnc_task04", 2];
        },
        nil, 6.0, true, true, "", "alive _target && _this distance _target < 4"
    ];
};
