if (!isServer) exitWith {};

[] spawn {
    while { true } do {
        {
            private _unit = _x;
            if (!isPlayer _unit && alive _unit && !(_unit getVariable ["LL_skillsApplied", false])) then {
                private _side = side _unit;
                private _type = toLower (typeOf _unit);
                private _weapon = toLower (primaryWeapon _unit);
                private _role = toLower (roleDescription _unit);

                if (_side == east) then {

                    _unit setSkill ["aimingAccuracy", 0.03 + random 0.08]; 
                    _unit setSkill ["aimingShake",    0.05 + random 0.12]; 
                    _unit setSkill ["aimingSpeed",    0.45 + random 0.30]; 
                    _unit setSkill ["spotDistance",   0.30 + random 0.30]; 
                    _unit setSkill ["spotTime",       0.10 + random 0.20]; 
                    _unit setSkill ["commanding",     0.20 + random 0.15]; 
                    _unit setSkill ["courage",        0.90 + random 0.10]; 
                    _unit setSkill ["general",        0.45];
                    _unit allowFleeing 0.02; 
                } else {
                    if (_side in [west, independent]) then {
                        private _isSniper = _role find "sniper" >= 0 || _role find "marksman" >= 0 || 
                                           _type find "sniper" >= 0 || _type find "marksman" >= 0 || 
                                           _weapon find "srifle" == 0 || _weapon find "dmr" >= 0;

                        private _isMG = _weapon find "lmg" >= 0 || _weapon find "mmg" >= 0 || _type find "ar" >= 0 || _type find "mg" >= 0;

                        if (_isSniper) then {

                            _unit setSkill ["aimingAccuracy", 0.90 + random 0.10];
                            _unit setSkill ["aimingShake",    0.85 + random 0.15];
                            _unit setSkill ["aimingSpeed",    0.90 + random 0.10];
                            _unit setSkill ["spotDistance",   0.90 + random 0.10];
                            _unit setSkill ["spotTime",       0.90 + random 0.10];
                            _unit setSkill ["commanding",     0.90 + random 0.10];
                            _unit setSkill ["general",        0.90];
                        } else {
                            if (_isMG) then {

                                _unit setSkill ["aimingAccuracy", 0.45 + random 0.15];
                                _unit setSkill ["aimingShake",    0.55 + random 0.15];
                                _unit setSkill ["aimingSpeed",    0.70 + random 0.20];
                                _unit setSkill ["spotDistance",   0.80 + random 0.15];
                                _unit setSkill ["spotTime",       0.80 + random 0.15];
                                _unit setSkill ["commanding",     0.80 + random 0.20];
                                _unit setSkill ["reloadSpeed",    0.90];
                                _unit setSkill ["general",        0.75];
                            } else {

                                _unit setSkill ["aimingAccuracy", 0.50 + random 0.15];
                                _unit setSkill ["aimingShake",    0.60 + random 0.15];
                                _unit setSkill ["aimingSpeed",    0.85 + random 0.15];
                                _unit setSkill ["spotDistance",   0.80 + random 0.15];
                                _unit setSkill ["spotTime",       0.85 + random 0.10]; 
                                _unit setSkill ["commanding",     0.80 + random 0.20]; 
                                _unit setSkill ["general",        0.75];
                            };
                        };
                        _unit allowFleeing 0.05;
                    };
                };

                _unit setVariable ["LL_skillsApplied", true, true];
            };
        } forEach allUnits;

        sleep 20;
    };
};
