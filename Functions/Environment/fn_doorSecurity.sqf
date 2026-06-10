if (!isServer) exitWith {};

[] spawn {
    private _OPEN_DIST     = 6;      
    private _CLOSE_DELAY   = 12;     
    private _CHECK_FREQ    = 0.8;    

    private _doorCache     = createHashMap;  

    while {true} do {
        sleep _CHECK_FREQ;

        private _aiUnits = allUnits select {
            alive _x &&
            !isPlayer _x &&
            side _x != west &&
            vehicle _x == _x
        };

        if (_aiUnits isEqualTo []) then { continue; };

        private _currentTime = time;

        private _nearBuildings = [];
        {
            private _pos = getPosATL _x;
            {
                if !(_x in _nearBuildings) then {
                    _nearBuildings pushBack _x;
                };
            } forEach (nearestObjects [_pos, ["House", "Building"], _OPEN_DIST + 8]);
        } forEach _aiUnits;

        {
            private _bldg = _x;
            private _bldgKey = hashValue _bldg;
            private _bldgData = _doorCache getOrDefault [_bldgKey, []];

            if (_bldgData isEqualTo []) then {
                private _anims = (animationNames _bldg) select { (toLowerANSI _x) find "door" >= 0 };
                _bldgData = [_anims, 0, _bldg]; 
                _doorCache set [_bldgKey, _bldgData];
            };

            _bldgData params ["_doorAnims", "_lastOpened", "_cachedBldg"];

            if (_doorAnims isEqualTo []) then { continue; };

            private _aiNearby = _aiUnits findIf { _x distance _bldg < _OPEN_DIST } != -1;

            if (_aiNearby) then {

                if (_currentTime - _lastOpened > 1.5) then {  
                    {
                        private _phase = _bldg animationPhase _x;
                        if (_phase < 0.95) then {

                            _bldg animate [_x, 1, 0.8];           
                            _bldg animateDoor [_x, 1, false];     

                            private _soundPos = _bldg modelToWorld (getCenterOfMass _bldg);
                            playSound3D ["A3\Sounds_F\environment\doors\DoorMetalSingleOpen_1.wss", _bldg, false, _soundPos, 0.25, 0.8, 20];
                        };
                    } forEach _doorAnims;

                    _bldgData set [1, _currentTime];
                    _doorCache set [_bldgKey, _bldgData];
                };
            } 
            else {

                if (_currentTime - _lastOpened > _CLOSE_DELAY) then {
                    {
                        if (_bldg animationPhase _x > 0.05) then {
                            _bldg animate [_x, 0, 0.6];  
                        };
                    } forEach _doorAnims;

                    _bldgData set [1, _currentTime - _CLOSE_DELAY + 3];
                    _doorCache set [_bldgKey, _bldgData];
                };
            };
        } forEach _nearBuildings;

        if (count _doorCache > 120) then {
            private _refPos = getPosATL (selectRandom _aiUnits);
            private _toRemove = [];
            {
                private _key = _x;
                private _data = _y;
                private _cachedObj = _data select 2;
                if (isNull _cachedObj || { _cachedObj distance2D _refPos > 300 }) then {
                    _toRemove pushBack _key;
                };
            } forEach _doorCache;
            { _doorCache deleteAt _x; } forEach _toRemove;
        };
    };
};
