if (!hasInterface) exitWith {};

if (isNil "LL_fnc_applyRoE") then {
    LL_fnc_applyRoE = {
        params ["_grp", "_combatMode", "_behaviour", "_speedMode", "_formation", "_unitPos", "_disableAutocombat", "_name"];

        _grp setCombatMode _combatMode;
        _grp setBehaviourStrong _behaviour;
        _grp setSpeedMode _speedMode;
        _grp setFormation _formation;

        {
            if (!isPlayer _x && alive _x && vehicle _x == _x) then {
                _x setUnitPos _unitPos;
                if (_disableAutocombat) then {
                    _x disableAI "AUTOCOMBAT";
                    _x disableAI "SUPPRESSION";
                } else {
                    _x enableAI "AUTOCOMBAT";
                    _x enableAI "SUPPRESSION";
                };
                _x setVariable ["LL_CurrentRoE", _name, false];
            };
        } forEach units _grp;

        private _frName = switch (_name) do {
            case "STEALTH": {"Infiltration"};
            case "PATROL":  {"Patrouille"};
            case "VIGILANT": {"Vigilance"};
            case "ASSAULT": {"Assaut tactique"};
            case "CHARGE":  {"Charge agressive"};
            case "DEFEND":  {"Position défensive"};
            default {"Par défaut"};
        };
        
        ["STR_LL_RoeAction_Changed", [_frName]] call LL_fnc_radioMessage;
    };
};

private _fnc_addRoeActions = {
    params ["_unit"];
    
    if (_unit getVariable ["LL_Action_Roe_Added", false]) exitWith {};
    _unit setVariable ["LL_Action_Roe_Added", true];

    private _cond = "alive _target && leader group _target == _target && ({!isPlayer _x && alive _x && vehicle _x == _x} count units group _target > 0)";

    _unit addAction [
        localize "STR_LL_RoeAction_Infiltration",
        { ([group (_this select 1)] + (_this select 3)) call LL_fnc_applyRoE; },
        ["BLUE", "STEALTH", "LIMITED", "STAG COLUMN", "MIDDLE", false, "STEALTH"],
        7.4, false, true, "", _cond
    ];

    _unit addAction [
        localize "STR_LL_RoeAction_Patrol",
        { ([group (_this select 1)] + (_this select 3)) call LL_fnc_applyRoE; },
        ["GREEN", "SAFE", "NORMAL", "COLUMN", "AUTO", false, "PATROL"],
        7.3, false, true, "", _cond
    ];

    _unit addAction [
        localize "STR_LL_RoeAction_Vigilance",
        { ([group (_this select 1)] + (_this select 3)) call LL_fnc_applyRoE; },
        ["YELLOW", "AWARE", "NORMAL", "WEDGE", "AUTO", false, "VIGILANT"],
        7.2, false, true, "", _cond
    ];

    _unit addAction [
        localize "STR_LL_RoeAction_Assault",
        { ([group (_this select 1)] + (_this select 3)) call LL_fnc_applyRoE; },
        ["RED", "COMBAT", "NORMAL", "WEDGE", "AUTO", false, "ASSAULT"],
        7.1, false, true, "", _cond
    ];

    _unit addAction [
        localize "STR_LL_RoeAction_Charge",
        { ([group (_this select 1)] + (_this select 3)) call LL_fnc_applyRoE; },
        ["RED", "COMBAT", "FULL", "VEE", "UP", true, "CHARGE"],
        7.0, false, true, "", _cond
    ];

    _unit addAction [
        localize "STR_LL_RoeAction_Defense",
        { 
            ([group (_this select 1)] + (_this select 3)) call LL_fnc_applyRoE;
            { if (!isPlayer _x && alive _x) then { _x doWatch (_x getRelPos [30, random 360]); }; } forEach units group (_this select 1);
        },
        ["YELLOW", "COMBAT", "LIMITED", "DIAMOND", "MIDDLE", false, "DEFEND"],
        6.9, false, true, "", _cond
    ];

    _unit addAction [
        localize "STR_LL_RoeAction_Reset",
        { ([group (_this select 1)] + (_this select 3)) call LL_fnc_applyRoE; },
        ["YELLOW", "AWARE", "NORMAL", "WEDGE", "AUTO", false, "VIGILANT"],
        6.8, false, true, "", _cond
    ];
};

[_fnc_addRoeActions] spawn {
    params ["_fnc_addRoeActions"];
    private _lastPlayer = objNull;
    while {true} do {
        waitUntil { sleep 1; player != _lastPlayer && !isNull player };
        _lastPlayer = player;
        [_lastPlayer] call _fnc_addRoeActions;
    };
};
