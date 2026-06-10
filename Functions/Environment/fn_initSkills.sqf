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
                    _unit setSkill ["aimingAccuracy", 0.12 + random 0.18];
                    _unit setSkill ["aimingShake",    0.15 + random 0.25];
                    _unit setSkill ["aimingSpeed",    0.20 + random 0.35];
                    _unit setSkill ["spotDistance",   0.45 + random 0.40];
                    _unit setSkill ["spotTime",       0.30 + random 0.40];
                    _unit setSkill ["courage",        0.7 + random 0.3];
                    _unit setSkill ["general",        0.55];
                    _unit allowFleeing (0.1 + random 0.3);
                } else {
                    if (_side in [west, independent]) then {
                        private _isSniper = _role find "sniper" >= 0 || _role find "marksman" >= 0 || 
                                           _type find "sniper" >= 0 || _type find "marksman" >= 0 || 
                                           _weapon find "srifle" == 0 || _weapon find "dmr" >= 0;

                        private _isMG = _weapon find "lmg" >= 0 || _weapon find "mmg" >= 0 || _type find "ar" >= 0 || _type find "mg" >= 0;

                        if (_isSniper) then {
                            _unit setSkill ["aimingAccuracy", 0.65 + random 0.20];
                            _unit setSkill ["aimingShake",    0.70 + random 0.20];
                            _unit setSkill ["spotDistance",   0.85 + random 0.10];
                            _unit setSkill ["spotTime",       0.75 + random 0.15];
                            _unit setSkill ["general",        0.85];
                        } else {
                            if (_isMG) then {
                                _unit setSkill ["aimingAccuracy", 0.40 + random 0.20];
                                _unit setSkill ["aimingSpeed",    0.55 + random 0.20];
                                _unit setSkill ["reloadSpeed",    0.85];
                            } else {
                                _unit setSkill ["aimingAccuracy", 0.45 + random 0.22];
                                _unit setSkill ["aimingShake",    0.50 + random 0.20];
                                _unit setSkill ["aimingSpeed",    0.55 + random 0.20];
                                _unit setSkill ["spotDistance",   0.65 + random 0.20];
                                _unit setSkill ["general",        0.70];
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
