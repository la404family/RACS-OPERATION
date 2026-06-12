if (!hasInterface) exitWith {};

[] spawn {
    waitUntil { sleep 0.5; !isNull (missionNamespace getVariable ["LL_Task04_Truck", objNull]) };
    private _truck = missionNamespace getVariable ["LL_Task04_Truck", objNull];

    _truck addAction [
        format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_04_Action"],
        {
            params ["_target", "_caller", "_actionId"];
            if (missionNamespace getVariable ["LL_Task04_Triggered", false]) exitWith {};
            missionNamespace setVariable ["LL_Task04_Triggered", true, true];
            
            removeAllActions _target;
            _caller playActionNow "PutDown";

            ["extract", [_target, _caller]] remoteExec ["LL_fnc_task04", 2];
        },
        nil, 6.0, true, true, "", "alive _target && _this distance _target < 15"
    ];
};
