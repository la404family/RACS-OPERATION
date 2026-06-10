#include "..\macros.hpp"

if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addHelicopterActions = {
        params ["_unit"];
        
        if (_unit getVariable ["LL_Heli_Actions_Added", false]) exitWith {};
        _unit setVariable ["LL_Heli_Actions_Added", true];

        private _requestWithMap = {
            params ["_type", "_target", "_actionId"];
            
            if (_type == "VEHICULE" && { missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false] }) exitWith {
                systemChat (localize "STR_TAG_Msg_Vehicle_Denied_Once");
            };
            if (_type == "CAS") then {
                private _cooldown = missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0];
                if (time < _cooldown) exitWith {
                    private _remaining = ceil (_cooldown - time);
                    systemChat (format [localize "STR_TAG_Msg_CAS_Cooldown", _remaining]);
                    true 
                };
            };
            if (_type == "CAS" && { time < missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0] }) exitWith {};

            openMap true;
            systemChat "QG : Cliquez sur la carte pour définir la zone de l'hélicoptère.";
            LL_Heli_MapClick = true;
            player setVariable ["LL_Heli_PendingRequest", [_type, _target, _actionId]];

            addMissionEventHandler ["MapSingleClick", {
                params ["_units", "_pos", "_alt", "_shift"];
                if !(missionNamespace getVariable ["LL_Heli_MapClick", false]) exitWith {};
                LL_Heli_MapClick = false;
                removeMissionEventHandler ["MapSingleClick", _thisEventHandler];
                openMap false;
                
                private _req = player getVariable ["LL_Heli_PendingRequest", []];
                if (count _req > 0) then {
                    _req params ["_type", "_target", "_actionId"];
                    [_type, _pos, player, _target, _actionId] remoteExec ["LL_fnc_requestHelicopter", 2];
                };
            }];
        };

        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Heli_Action_Supply"],
            {
                params ["_target", "_caller", "_actionId"];
                ["LIVRAISON", _target, _actionId] call _requestWithMap;
            },
            nil, 3.3, false, true, "", "(alive _target && leader (group _target) isEqualTo _target) || _target getVariable ['LL_Spectating', false]"
        ];

        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_TAG_Heli_Action_Vehicle"],
            {
                params ["_target", "_caller", "_actionId"];
                ["VEHICULE", _target, _actionId] call _requestWithMap;
            },
            nil, 3.1, false, true, "", "(alive _target && leader (group _target) isEqualTo _target) || _target getVariable ['LL_Spectating', false]"
        ];

        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_TAG_Heli_Action_CAS"],
            {
                params ["_target", "_caller", "_actionId"];
                ["CAS", _target, _actionId] call _requestWithMap;
            },
            nil, 2.9, false, true, "", "(alive _target && leader (group _target) isEqualTo _target) || _target getVariable ['LL_Spectating', false]"
        ];

        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Heli_Action_Reinforcements"],
            {
                params ["_target", "_caller", "_actionId"];
                ["DEBARQUEMENT", _target, _actionId] call _requestWithMap;
            },
            nil, 2.7, false, true, "", "(alive _target && leader (group _target) isEqualTo _target) || _target getVariable ['LL_Spectating', false]"
        ];

    };

    private _lastPlayer = objNull;
    while {true} do {
        waitUntil { sleep 1; player != _lastPlayer };  
        
        _lastPlayer = player;
        if (!isNull _lastPlayer) then {
            [_lastPlayer] call _fnc_addHelicopterActions;
        };
    };
};
