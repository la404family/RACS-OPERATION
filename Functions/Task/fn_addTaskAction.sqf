if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addAction = {
        params ["_unit"];
        if (_unit getVariable ["LL_Task_Action_Added", false]) exitWith {};
        _unit setVariable ["LL_Task_Action_Added", true];

        _unit addAction [
            format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Action_RequestTask"],
            {
                ["REQUEST"] remoteExec ["LL_fnc_taskManager", 2];
            },
            nil, 7.45, false, true, "", "alive _target && leader (group _target) isEqualTo _target && !(missionNamespace getVariable ['LL_g_taskInProgress', false])"
        ];
    };

    private _lastPlayer = objNull;
    while { true } do {
        waitUntil { sleep 1; player != _lastPlayer };
        _lastPlayer = player;
        if (!isNull _lastPlayer) then {
            [_lastPlayer] call _fnc_addAction;
        };
    };
};
