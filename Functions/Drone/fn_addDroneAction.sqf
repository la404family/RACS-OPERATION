if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addAction = {
        params ["_unit"];
        if (_unit getVariable ["LL_Drone_Action_Added", false]) exitWith {};
        _unit setVariable ["LL_Drone_Action_Added", true];

        _unit addAction [
            localize "STR_Drone_Surveillance",
            {
                params ["_target", "_caller", "_actionId"];
                if (missionNamespace getVariable ["LL_Drone_Active", false]) exitWith {
                    ["STR_Drone_AlreadyActive_Wait"] call LL_fnc_radioMessage;
                };
                openMap true;
                ["STR_Drone_ClickMap"] call LL_fnc_radioMessage;
                LL_Drone_MapClick = true;

                private _ehId = addMissionEventHandler ["MapSingleClick", {
                    params ["_units", "_pos", "_alt", "_shift"];
                    if !(LL_Drone_MapClick) exitWith {};
                    LL_Drone_MapClick = false;
                    removeMissionEventHandler ["MapSingleClick", _thisEventHandler];
                    openMap false;
                    [player, _pos] remoteExec ["LL_fnc_requestDrone", 2];
                    ["STR_Drone_EnRoute", [round (_pos select 0), round (_pos select 1)]] call LL_fnc_radioMessage;
                }];
            },
            nil, 8.0, false, true, "", "alive _target && (leader (group _target) isEqualTo _target || _target getVariable ['LL_Spectating', false])"
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
