params ["_leader"];

if (!local _leader) exitWith {};

private _units = (units group _leader) select {
    !isPlayer _x && alive _x && vehicle _x == _x && _x distance _leader > 15
};

if (_units isEqualTo []) exitWith {};

{
    private _targetPos = _leader getRelPos [4 + (_forEachIndex * 1.5), 180 + (random 40 - 20)];
    _x doMove _targetPos;
    _x setVariable ["LL_RallyStuckTime", 0];
    _x setVariable ["LL_RallyBrainwashed", false];
} forEach _units;

[_leader, _units] spawn {
    params ["_leader", "_units"];
    private _timeout = time + 30;

    while { time < _timeout } do {
        sleep 2;

        private _activeUnits = _units select { alive _x && _x distance _leader > 8 };
        if (_activeUnits isEqualTo []) exitWith {};

        {
            private _u = _x;

            private _targetPos = _leader getRelPos [4 + (_forEachIndex * 1.5), 180 + (random 40 - 20)];
            _u doMove _targetPos;

            private _speed = speed _u;
            private _brainwashed = _u getVariable ["LL_RallyBrainwashed", false];

            if (_speed > 1 && _brainwashed) then {
                _u enableAI "AUTOCOMBAT";
                _u enableAI "TARGET";
                _u enableAI "AUTOTARGET";
                _u enableAI "FSM";
                _u setBehaviourStrong "AWARE";
                _u setCombatMode "YELLOW";
                _u setUnitPos "AUTO";
                _u forceSpeed -1;
                _u setVariable ["LL_RallyBrainwashed", false];
                _u setVariable ["LL_RallyStuckTime", 0];
            };

            if (_speed < 0.5 && _u distance _leader > 12) then {
                private _stuckTime = (_u getVariable ["LL_RallyStuckTime", 0]) + 2;
                _u setVariable ["LL_RallyStuckTime", _stuckTime];

                if (_stuckTime == 2 && !_brainwashed) then {
                    _u disableAI "AUTOCOMBAT";
                    _u disableAI "TARGET";
                    _u disableAI "AUTOTARGET";
                    _u disableAI "FSM";
                    _u setBehaviourStrong "CARELESS";
                    _u setCombatMode "BLUE";
                    _u setUnitPos "UP";
                    _u forceSpeed -1;
                    _u setVariable ["LL_RallyBrainwashed", true];
                };

                if (_stuckTime == 6) then {
                    private _devPos = _u getRelPos [6, random 360];
                    _devPos = [_devPos, 0, 5, 1, 0, 0.5, 0] call BIS_fnc_findSafePos;
                    _u doMove _devPos;
                };

                if (_stuckTime >= 12) then {
                    private _tpPos = _leader getRelPos [3 + random 3, 160 + random 40];
                    private _safeTp = [_tpPos, 0, 10, 1, 0, 0.5, 0] call BIS_fnc_findSafePos;
                    if (count _safeTp == 2) then { _safeTp pushBack 0; };
                    _u setPosATL _safeTp;
                    _u setVariable ["LL_RallyStuckTime", 0];
                };
            } else {
                if (!_brainwashed) then {
                    _u setVariable ["LL_RallyStuckTime", 0];
                };
            };
        } forEach _activeUnits;
    };

    {
        if (alive _x) then {
            _x enableAI "AUTOCOMBAT";
            _x enableAI "TARGET";
            _x enableAI "AUTOTARGET";
            _x enableAI "FSM";
            _x setBehaviourStrong "AWARE";
            _x setCombatMode "YELLOW";
            _x setUnitPos "AUTO";
            _x forceSpeed -1;
            _x doFollow _leader;
        };
    } forEach _units;
};

true
