if (!hasInterface) exitWith {};

_this spawn {
    params [["_hostageParam", objNull, [objNull]], ["_netId", "", [""]], ["_varName", "", [""]]];

    private _hostage = _hostageParam;
    if (isNull _hostage) then {
        private _timeout = time + 30;
        waitUntil {
            sleep 0.5;
            if (_netId != "") then { _hostage = objectFromNetId _netId; };
            if (isNull _hostage && _varName != "") then { _hostage = missionNamespace getVariable [_varName, objNull]; };
            !isNull _hostage || time > _timeout
        };
    };

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
        nil, 6.0, true, true, "", "alive _target && _this distance _target < 4", 4
    ];
};
