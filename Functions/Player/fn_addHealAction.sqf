if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addAction = {
        params ["_unit"];
        
        if (_unit getVariable ["LL_Action_Heal_Added", false]) exitWith {};
        _unit setVariable ["LL_Action_Heal_Added", true];

        _unit addAction [
            "<t color='#00FF00'>Soin Automatique IA</t>",
            {
                params ["_target", "_caller"];

                private _aiUnits = (units group _caller) select {
                    !isPlayer _x && alive _x && damage _x > 0.15 && vehicle _x == _x
                };

                private _healers = _aiUnits select {
                    "FirstAidKit" in items _x || "Medikit" in items _x
                };

                if (_healers isEqualTo []) exitWith {
                    if (_aiUnits isNotEqualTo []) then {
                        systemChat "QG : Négatif ! Aucune IA ne possède de kit de soin.";
                    } else {
                        systemChat "QG : Négatif ! Aucune IA blessée nécessitant des soins.";
                    };
                };

                {
                    [_x, _forEachIndex] spawn {
                        params ["_unit", "_delay"];

                        sleep (_delay * 0.7);

                        if (!alive _unit || damage _unit <= 0.1) exitWith {};

                        _unit setBehaviour "AWARE";
                        _unit setUnitPos "MIDDLE";
                        doStop _unit;
                        _unit forceSpeed 0;
                        _unit disableAI "PATH";
                        _unit disableAI "AUTOCOMBAT";

                        sleep 0.8;

                        if ("Medikit" in items _unit) then {
                            _unit action ["HealSoldierSelf", _unit];
                            waitUntil {sleep 0.5; damage _unit < 0.05 || !alive _unit};
                        } else {
                            for "_i" from 1 to 3 do {
                                if (damage _unit < 0.25) exitWith {};
                                _unit action ["HealSoldierSelf", _unit];
                                sleep 4;
                            };
                        };

                        if (alive _unit) then {
                            _unit enableAI "PATH";
                            _unit enableAI "AUTOCOMBAT";
                            _unit forceSpeed -1;
                            _unit setUnitPos "AUTO";
                            _unit doFollow (leader group _unit);
                        };
                    };
                } forEach _healers;

                systemChat format ["QG : %1 IA en cours d'auto-soin...", count _healers];
            },
            [],
            5.4,
            false,
            true,
            "",
            "alive _target && leader group _target == _target && ({!isPlayer _x && alive _x && vehicle _x == _x} count (units group _target) > 0)"
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
