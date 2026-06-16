if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addAction = {
        params ["_unit"];
        if (_unit getVariable ["LL_Heli_Actions_Added", false]) exitWith {};
        _unit setVariable ["LL_Heli_Actions_Added", true];

        private _fnc_requestWithMap = {
            params ["_type"];
            if (missionNamespace getVariable ["LL_Heli_Jammed", false]) exitWith {
                ["STR_LL_Heli_Action_Jammed"] call LL_fnc_radioMessage;
            };
            if (_type == "VEHICULE" && { missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false] }) exitWith {
                ["STR_LL_Heli_Action_VehicleAlready"] call LL_fnc_radioMessage;
            };
            if (_type == "CAS") then {
                private _cooldown = missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0];
                if (time < _cooldown) exitWith {
                    private _remaining = ceil (_cooldown - time);
                    ["STR_LL_Heli_Action_CASCooldown", [_remaining]] call LL_fnc_radioMessage;
                };
            };

            openMap true;
            ["STR_LL_Heli_Action_ClickMap"] call LL_fnc_radioMessage;
            missionNamespace setVariable ["LL_Heli_MapClick", true];
            missionNamespace setVariable ["LL_Heli_PendingType", _type];

            addMissionEventHandler ["MapSingleClick", {
                params ["_units", "_pos", "_alt", "_shift"];
                if !(missionNamespace getVariable ["LL_Heli_MapClick", false]) exitWith {};
                missionNamespace setVariable ["LL_Heli_MapClick", false];
                removeMissionEventHandler ["MapSingleClick", _thisEventHandler];
                openMap false;
                private _type = missionNamespace getVariable ["LL_Heli_PendingType", ""];
                [_type, _pos, player] remoteExec ["LL_fnc_requestHelicopter", 2];
                ["STR_LL_Heli_Action_EnRoute", [round (_pos select 0), round (_pos select 1), _type]] call LL_fnc_radioMessage;
            }];
        };

        missionNamespace setVariable ["LL_fnc_requestWithMap", _fnc_requestWithMap];

        _unit addAction [
            localize "STR_LL_Heli_Action_Ammo",
            {
                ["LIVRAISON"] call (missionNamespace getVariable ["LL_fnc_requestWithMap", {}]);
            },
            nil, 7.9, false, true, "", "alive _target && (leader (group _target) isEqualTo _target || _target getVariable ['LL_Spectating', false])"
        ];

        _unit addAction [
            localize "STR_LL_Heli_Action_Vehicle",
            {
                ["VEHICULE"] call (missionNamespace getVariable ["LL_fnc_requestWithMap", {}]);
            },
            nil, 7.8, false, true, "", "alive _target && (leader (group _target) isEqualTo _target || _target getVariable ['LL_Spectating', false])"
        ];

        _unit addAction [
            localize "STR_LL_Heli_Action_CAS",
            {
                ["CAS"] call (missionNamespace getVariable ["LL_fnc_requestWithMap", {}]);
            },
            nil, 7.7, false, true, "", "alive _target && (leader (group _target) isEqualTo _target || _target getVariable ['LL_Spectating', false])"
        ];

        _unit addAction [
            localize "STR_LL_Heli_Action_Reinforce",
            {
                ["DEBARQUEMENT"] call (missionNamespace getVariable ["LL_fnc_requestWithMap", {}]);
            },
            nil, 7.6, false, true, "", "alive _target && (leader (group _target) isEqualTo _target || _target getVariable ['LL_Spectating', false])"
        ];

        _unit addAction [
            localize "STR_LL_Heli_Action_Extract",
            {
                ["EMBARQUEMENT"] call (missionNamespace getVariable ["LL_fnc_requestWithMap", {}]);
            },
            nil, 7.5, false, true, "", "alive _target && (leader (group _target) isEqualTo _target || _target getVariable ['LL_Spectating', false])"
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
