#include "..\macros.hpp"

if (!hasInterface) exitWith {};

params [["_crate", objNull, [objNull]]];

if (isNull _crate) exitWith {};

_crate setVariable ["LL_Resupply_InProgress", false, true];

_crate addAction [
    format ["<t color='#FFD700'>%1</t>", localize "STR_LL_Action_Resupply"],
    {
        params ["_target", "_caller", "_actionId"];

        if (_target getVariable ["LL_Resupply_InProgress", false]) exitWith {};
        _target setVariable ["LL_Resupply_InProgress", true, true];

        private _squadAI = (units group _caller) select {
            !isPlayer _x && alive _x && vehicle _x == _x
        };

        if (count _squadAI == 0) exitWith {
            systemChat localize "STR_LL_Msg_Resupply_NoAI";
            _target setVariable ["LL_Resupply_InProgress", false, true];
        };

        _caller playActionNow "gestureAdvance";
        systemChat localize "STR_LL_Msg_Resupply_Start";

        _target removeAction _actionId;

        [_target, _squadAI, _caller] spawn {
            params ["_crate", "_squadAI", "_leader"];

            private _cratePos = getPos _crate;
            private _crateDir = getDir _crate;

            private _fnc_resupply = {
                params ["_unit", "_crate"];
                if (!alive _unit || isNull _crate) exitWith {};

                private _pw = primaryWeapon _unit;
                if (_pw != "") then {
                    private _pwMags = getArray (configFile >> "CfgWeapons" >> _pw >> "magazines");
                    if (count _pwMags > 0) then {
                        private _magClass = _pwMags # 0;
                        private _currentCount = { _x == _magClass } count (magazines _unit);
                        private _needed = (8 - _currentCount) max 0;
                        for "_m" from 1 to _needed do { _unit addMagazine _magClass; };
                    };
                };

                private _hw = handgunWeapon _unit;
                if (_hw != "") then {
                    private _hwMags = getArray (configFile >> "CfgWeapons" >> _hw >> "magazines");
                    if (count _hwMags > 0) then {
                        private _magClass = _hwMags # 0;
                        private _currentCount = { _x == _magClass } count (magazines _unit);
                        private _needed = (4 - _currentCount) max 0;
                        for "_m" from 1 to _needed do { _unit addMagazine _magClass; };
                    };
                };

                private _sw = secondaryWeapon _unit;
                if (_sw != "") then {
                    private _swMags = getArray (configFile >> "CfgWeapons" >> _sw >> "magazines");
                    if (count _swMags > 0) then {
                        private _magClass = _swMags # 0;
                        private _currentCount = { _x == _magClass } count (magazines _unit);
                        private _needed = (3 - _currentCount) max 0;
                        for "_m" from 1 to _needed do { _unit addMagazine _magClass; };
                    };
                };

                private _grenadeCount = { toLower _x find "grenade" != -1 } count (magazines _unit);
                if (_grenadeCount < 3) then {
                    for "_g" from 1 to (3 - _grenadeCount) do { _unit addMagazine "CUP_HandGrenade_M67"; };
                };
                private _smokeCount = { _x == "SmokeShell" } count (magazines _unit);
                if (_smokeCount < 2) then {
                    for "_s" from 1 to (2 - _smokeCount) do { _unit addMagazine "SmokeShell"; };
                };

                private _fak = { _x == "FirstAidKit" } count (items _unit);
                if (_fak < 3) then {
                    for "_f" from 1 to (3 - _fak) do { _unit addItem "FirstAidKit"; };
                };
            };

            {
                private _unit = _x;
                if (alive _unit) then {
                    
                    private _dirToUnit = _cratePos getDir (getPos _unit);
                    private _approachPos = _crate getPos [0.1, _dirToUnit];

                    _unit setSpeedMode "NORMAL";
                    _unit setUnitPos "UP";
                    _unit doMove _approachPos;

                    private _timeout = time + 12;
                    waitUntil {
                        sleep 0.5;
                        !alive _unit || (_unit distance2D _approachPos < 0.2) || time > _timeout
                    };

                    if (alive _unit) then {
                        
                        _unit doWatch _crate;
                        sleep 0.5;

                        [_unit, _crate] call _fnc_resupply;

                        [_unit, "ReloadMagazine"] remoteExecCall ["playActionNow", owner _unit];

                        sleep 4.0;

                        _unit doWatch objNull;
                        _unit doFollow _leader;
                        
                        sleep 1.0;
                    };
                };
            } forEach _squadAI;

            systemChat localize "STR_LL_Msg_Resupply_Done";

            if (!isNull _crate && { alive _crate }) then {
                _crate setVariable ["LL_Resupply_InProgress", false, true];
                [_crate] call LL_fnc_addResupplyAction;
            };
        };
    },
    [],
    6.0,       
    true,      
    true,      
    "",
    
    "leader group player == player && { !isPlayer _x } count (units group player) > 0 && !(_target getVariable ['LL_Resupply_InProgress', false])"
];
