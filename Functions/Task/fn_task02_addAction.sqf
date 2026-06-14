if (!hasInterface) exitWith {};

_this spawn {
    params [["_bombParam", objNull, [objNull, ""]]];

    private _bomb = objNull;
    if (_bombParam isEqualType "") then {
        waitUntil {
            sleep 0.5;
            _bomb = objectFromNetId _bombParam;
            if (isNull _bomb) then {
                _bomb = missionNamespace getVariable [_bombParam, objNull];
            };
            !isNull _bomb
        };
    } else {
        _bomb = _bombParam;
    };

    if (isNull _bomb) exitWith {};

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
        "alive _target && _this distance _target < 4 && (_target getVariable ['LL_Bomb_Status', 'WAIT']) == 'WAIT'",
        4
    ];
};
