if (!hasInterface) exitWith {};

_this spawn {
    params [["_jammerParam", objNull, [objNull]], ["_netId", "", [""]]];

    private _jammer = _jammerParam;
    if (isNull _jammer) then {
        private _timeout = time + 30;
        waitUntil {
            sleep 0.5;
            if (_netId != "") then { _jammer = objectFromNetId _netId; };
            !isNull _jammer || time > _timeout
        };
    };

    if (isNull _jammer) exitWith {};

    _jammer addAction [
        format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_03_Action"],
        {
            params ["_target", "_caller", "_actionId"];

            if (_target getVariable ["LL_Task08_Triggered", false]) exitWith {};
            _target setVariable ["LL_Task08_Triggered", true, true];

            _target removeAction _actionId;

            ["plant", [_target, _caller]] remoteExec ["LL_fnc_task08", 2];
        },
        nil, 6.0, true, true, "", "alive _target && _this distance _target < 6 && (_target getVariable ['LL_Task_Status', 'WAIT'] == 'WAIT')", 6
    ];
};
