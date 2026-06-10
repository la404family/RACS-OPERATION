if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addAction = {
        params ["_unit"];
        if (_unit getVariable ["LL_Rally_Action_Added", false]) exitWith {};
        _unit setVariable ["LL_Rally_Action_Added", true];

        _unit addAction [
            localize "STR_LL_RallyAction_Title",
            {
                params ["_target", "_caller", "_actionId"];
                [_caller] call LL_fnc_forceRally;
            },
            nil, 6.5, false, true, "", "alive _target && leader (group _target) isEqualTo _target && ({!isPlayer _x && alive _x && vehicle _x == _x} count units group _target) > 0"
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
