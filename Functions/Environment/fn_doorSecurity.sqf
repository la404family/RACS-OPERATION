if (!isServer) exitWith {};

[] spawn {
    private _OPEN_DIST       = 4;    
    private _CLOSE_SAFE_DIST = 20;   
    private _CLOSE_DELAY     = 25;   
    private _CHECK_FREQ      = 0.8;

    private _doorCache = [];

    while {true} do {
        sleep _CHECK_FREQ;

        private _aiUnits = allUnits select {
            alive _x &&
            !isPlayer _x &&
            vehicle _x == _x
        };

        if (_aiUnits isEqualTo []) then { continue; };

        private _currentTime = time;

        private _nearBuildings = [];
        {
            private _pos = getPosATL _x;
            {
                _nearBuildings pushBackUnique _x;
            } forEach (nearestObjects [_pos, ["House", "Building"], _OPEN_DIST + 8]);
        } forEach _aiUnits;

        {
            private _bldg = _x;
            private _idx = _doorCache findIf { (_x select 0) == _bldg };
            private _bldgData = if (_idx != -1) then { (_doorCache select _idx) select 1 } else { [] };

            if (_bldgData isEqualTo []) then {
                private _anims = (animationNames _bldg) select { (toLowerANSI _x) find "door" >= 0 };
                private _doorDetails = [];
                {
                    private _animLower = toLowerANSI _x;
                    private _doorNum = 1;
                    private _startIdx = _animLower find "door";
                    if (_startIdx != -1) then {
                        private _sub = _animLower select [_startIdx + 4];
                        private _digits = [];
                        {
                            if (_x in ["0","1","2","3","4","5","6","7","8","9"]) then {
                                _digits pushBack _x;
                            };
                        } forEach (splitString [_sub, ""]);
                        if (count _digits > 0) then {
                            _doorNum = parseNumber (_digits joinString "");
                        };
                    };
                    _doorDetails pushBack [_x, _doorNum];
                } forEach _anims;

                _bldgData = [_doorDetails, 0, _bldg, false];
                _doorCache pushBack [_bldg, _bldgData];
                _idx = count _doorCache - 1;
            };

            _bldgData params [
                ["_doorDetails", [], [[]]],
                ["_lastOpened", 0, [0]],
                ["_cachedBldg", objNull, [objNull]],
                ["_isDoorOpen", false, [false]]
            ];

            if (_doorDetails isEqualTo []) then { continue; };

            private _aiNearDoor = _aiUnits findIf { _x distanceSqr _bldg < 16 } != -1;

            if (_aiNearDoor) then {
                if (!_isDoorOpen || _currentTime - _lastOpened > 2) then {
                    {
                        _x params ["_anim", "_doorNum"];

                        private _lockVal = _bldg getVariable [format ["bis_disabled_Door_%1", _doorNum], 0];
                        private _locked = (_lockVal isEqualTo 1) || (_lockVal isEqualTo true);
                        if (!_locked) then {
                            private _phase = _bldg animationPhase _anim;
                            if (_phase < 0.95) then {
                                _bldg animate [_anim, 1, 0.8];
                                _bldg animateDoor [_anim, 1, false];
                                private _soundPos = _bldg modelToWorld (getCenterOfMass _bldg);
                                playSound3D ["A3\Sounds_F\environment\doors\DoorMetalSingleOpen_1.wss", _bldg, false, _soundPos, 0.25, 0.8, 20];
                            };
                        };
                    } forEach _doorDetails;

                    _bldgData set [1, _currentTime];
                    _bldgData set [3, true];
                };
            }
            else {
                if (_isDoorOpen && _currentTime - _lastOpened > _CLOSE_DELAY) then {

                    private _anyUnitNear = (_aiUnits findIf { _x distanceSqr _bldg < 400 } != -1);

                    if (!_anyUnitNear) then {
                        _anyUnitNear = (allPlayers findIf { alive _x && _x distanceSqr _bldg < 400 } != -1);
                    };

                    if (!_anyUnitNear) then {
                        {
                            _x params ["_anim", "_doorNum"];
                            if (_bldg animationPhase _anim > 0.05) then {
                                _bldg animate [_anim, 0, 0.6];
                            };
                        } forEach _doorDetails;

                        _bldgData set [1, 0];
                        _bldgData set [3, false];
                    };
                };
            };
        } forEach _nearBuildings;

        if (count _doorCache > 120) then {
            private _refPos = getPosATL (selectRandom _aiUnits);
            private _toRemove = [];
            {
                private _cachedObj = _x select 0;
                if (isNull _cachedObj || { _cachedObj distance2D _refPos > 300 }) then {
                    _toRemove pushBack _x;
                };
            } forEach _doorCache;
            _doorCache = _doorCache - _toRemove;
        };
    };
};
