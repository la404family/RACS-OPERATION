if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addAction = {
        params ["_unit"];
        if (_unit getVariable ["LL_Drone_Action_Added", false]) exitWith {};
        _unit setVariable ["LL_Drone_Action_Added", true];

        _unit addAction [
            "<t color='#FFFFFF'>[DRONE] Surveillance</t>",
            {
                params ["_target", "_caller", "_actionId"];
                if (missionNamespace getVariable ["LL_Drone_Active", false]) exitWith {
                    systemChat "QG : Drone déjà en mission. Attendez son retour.";
                };
                openMap true;
                systemChat "QG : Cliquez sur la carte pour définir la zone de surveillance.";
                LL_Drone_MapClick = true;

                private _ehId = addMissionEventHandler ["MapSingleClick", {
                    params ["_units", "_pos", "_alt", "_shift"];
                    if !(LL_Drone_MapClick) exitWith {};
                    LL_Drone_MapClick = false;
                    removeMissionEventHandler ["MapSingleClick", _thisEventHandler];
                    openMap false;
                    [player, _pos] remoteExec ["LL_fnc_requestDrone", 2];
                    systemChat format ["QG : Drone en route vers la position [%1, %2].", round (_pos select 0), round (_pos select 1)];
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
