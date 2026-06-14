if (!hasInterface) exitWith {};

_this spawn {
    params [["_truckParam", objNull, [objNull, ""]]];

    private _truck = objNull;
    if (_truckParam isEqualType "") then {
        waitUntil {
            sleep 0.5;
            _truck = objectFromNetId _truckParam;
            if (isNull _truck) then {
                _truck = missionNamespace getVariable [_truckParam, objNull];
            };
            !isNull _truck
        };
    } else {
        _truck = _truckParam;
    };

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
        nil, 6.0, true, true, "", "alive _target && _this distance _target < 15", 15
    ];
};
