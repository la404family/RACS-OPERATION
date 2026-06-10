if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addAction = {
        params ["_unit"];
        if (_unit getVariable ["LL_Heli_Actions_Added", false]) exitWith {};
        _unit setVariable ["LL_Heli_Actions_Added", true];

        private _fnc_requestWithMap = {
            params ["_type"];
            if (_type == "VEHICULE" && { missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false] }) exitWith {
                systemChat "QG : Livraison de véhicule déjà effectuée.";
            };
            if (_type == "CAS") then {
                private _cooldown = missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0];
                if (time < _cooldown) exitWith {
                    private _remaining = ceil (_cooldown - time);
                    systemChat format ["QG : CAS en cooldown, encore %1s.", _remaining];
                };
            };

            openMap true;
            systemChat "QG : Cliquez sur la carte pour définir la zone de l'hélicoptère.";
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
                systemChat format ["QG : Hélicoptère en route vers [%1, %2]. Type: %3", round (_pos select 0), round (_pos select 1), _type];
            }];
        };

        missionNamespace setVariable ["LL_fnc_requestWithMap", _fnc_requestWithMap];

        _unit addAction [
            "<t color='#FFFFFF'>Demander une livraison (Heli)</t>",
            {
                ["LIVRAISON"] call (missionNamespace getVariable ["LL_fnc_requestWithMap", {}]);
            },
            nil, 3.3, false, true, "", "alive _target && (leader (group _target) isEqualTo _target || _target getVariable ['LL_Spectating', false])"
        ];

        _unit addAction [
            "<t color='#FFFFFF'>Demander un véhicule (Heli)</t>",
            {
                ["VEHICULE"] call (missionNamespace getVariable ["LL_fnc_requestWithMap", {}]);
            },
            nil, 3.1, false, true, "", "alive _target && (leader (group _target) isEqualTo _target || _target getVariable ['LL_Spectating', false])"
        ];

        _unit addAction [
            "<t color='#FFFFFF'>Demander un appui aérien CAS</t>",
            {
                ["CAS"] call (missionNamespace getVariable ["LL_fnc_requestWithMap", {}]);
            },
            nil, 2.9, false, true, "", "alive _target && (leader (group _target) isEqualTo _target || _target getVariable ['LL_Spectating', false])"
        ];

        _unit addAction [
            "<t color='#FFFFFF'>Demander des renforts (Heli)</t>",
            {
                ["DEBARQUEMENT"] call (missionNamespace getVariable ["LL_fnc_requestWithMap", {}]);
            },
            nil, 2.7, false, true, "", "alive _target && (leader (group _target) isEqualTo _target || _target getVariable ['LL_Spectating', false])"
        ];

        _unit addAction [
            "<t color='#FFFFFF'>Demander une extraction (Heli)</t>",
            {
                ["EMBARQUEMENT"] call (missionNamespace getVariable ["LL_fnc_requestWithMap", {}]);
            },
            nil, 2.5, false, true, "", "alive _target && (leader (group _target) isEqualTo _target || _target getVariable ['LL_Spectating', false])"
        ];

        systemChat "[DEBUG] Actions hélicoptère ajoutées avec succès.";
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
