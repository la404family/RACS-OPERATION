if (!hasInterface) exitWith {};

if (isNil "LL_Search_BuildingsNearby") then {
    LL_Search_BuildingsNearby = false;
};

[] spawn {
    while {true} do {
        sleep 2;
        if (alive player) then {
            private _buildings = nearestObjects [player, ["House", "Building"], 55];
            LL_Search_BuildingsNearby = (_buildings findIf { count (_x buildingPos -1) > 2 }) != -1;
        } else {
            LL_Search_BuildingsNearby = false;
        };
    };
};

private _fnc_addSearchAction = {
    params ["_unit"];

    if (_unit getVariable ["LL_Action_Search_Added", false]) exitWith {};
    _unit setVariable ["LL_Action_Search_Added", true];

    _unit addAction [
        "<t color='#FFFFFF'>[ESCOUADE] Fouille</t>",
        {
            params ["_target", "_caller", "_actionId", "_arguments"];

            private _center = getPosATL _caller;
            private _buildings = nearestObjects [_center, ["House", "Building"], 50];
            _buildings = _buildings select { count (_x buildingPos -1) > 1 };

            if (_buildings isEqualTo []) exitWith { systemChat "QG : Aucun bâtiment fouillable à proximité."; };

            private _markerName = format ["LL_SearchArea_%1", time];
            private _marker = createMarkerLocal [_markerName, _center];
            _marker setMarkerShapeLocal "ELLIPSE";
            _marker setMarkerSizeLocal [60, 60];
            _marker setMarkerColorLocal "ColorYellow";
            _marker setMarkerAlphaLocal 0.15; 
            _marker setMarkerBrushLocal "SolidBorder";

            private _squadAI = (units group _caller) select { !isPlayer _x && alive _x && vehicle _x == _x };
            if (_squadAI isEqualTo []) exitWith {
                deleteMarkerLocal _marker;
                systemChat "QG : Pas d'IA d'infanterie dans l'escouade.";
            };

            [_caller, "gestureAdvance"] remoteExec ["playActionNow", 0];

            [_buildings, _squadAI, _caller, _marker] spawn {
                params ["_buildings", "_squadAI", "_leader", "_marker"];

                private _searchStart = time;
                private _maxTime = 300; 

                {
                    private _building = _x;
                    if (time - _searchStart > _maxTime) exitWith {};

                    private _positions = _building buildingPos -1;
                    if (_positions isEqualTo []) then {continue};

                    private _posData = _positions apply { [_x select 2, _x] };
                    _posData sort true;
                    _positions = _posData apply { _x select 1 };

                    {
                        private _unit = _x;
                        if (alive _unit) then {
                            _unit disableAI "AUTOCOMBAT";
                            _unit disableAI "SUPPRESSION";
                            _unit setUnitPos "UP";
                            _unit setBehaviour "AWARE";
                            _unit setSpeedMode "FULL";
                            _unit setCombatMode "YELLOW";
                            
                            private _pos = [];
                            if (_positions isNotEqualTo []) then {
                                _pos = _positions deleteAt 0;
                            } else {
                                
                                _pos = _building getRelPos [8 + random 7, random 360];
                            };

                            _unit doMove _pos;
                            _unit moveTo _pos;

                            [_unit, _pos, _searchStart, _maxTime] spawn {
                                params ["_unit", "_targetPos", "_searchStart", "_maxTime"];
                                private _lastPos = getPosATL _unit;
                                private _stuckCount = 0;

                                while {alive _unit && time - _searchStart < _maxTime} do {
                                    sleep 2.5;
                                    private _dist = _unit distance _targetPos;

                                    if (_dist < 2.5) exitWith { 
                                        
                                        doStop _unit;
                                        _unit setUnitPos "UP";
                                        for "_k" from 1 to 3 do {
                                            _unit doWatch (_unit getRelPos [20, (random 180) - 90]);
                                            sleep (2 + random 3);
                                        };
                                    };

                                    if (_unit distance _lastPos < 1 && _dist > 3) then {
                                        _stuckCount = _stuckCount + 1;
                                    } else {
                                        _stuckCount = 0;
                                    };
                                    _lastPos = getPosATL _unit;

                                    if (_stuckCount >= 4) then {
                                        doStop _unit;
                                        sleep 0.2;
                                        _unit commandMove _targetPos;
                                        _unit moveTo _targetPos;
                                        _stuckCount = 0;
                                    };
                                };
                            };
                            sleep 0.5; 
                        };
                    } forEach _squadAI;

                    private _buildingTimeout = time + 45;
                    waitUntil {
                        sleep 2;
                        
                        private _moving = {alive _x && !unitReady _x} count _squadAI;
                        _moving == 0 || time > _buildingTimeout || time - _searchStart > _maxTime
                    };

                    private _needsDescent = false;
                    private _lowestPos = [];
                    private _allBPos = _building buildingPos -1;
                    
                    if (_allBPos isNotEqualTo []) then {
                        private _bPosData = _allBPos apply { [_x select 2, _x] };
                        _bPosData sort true;
                        _lowestPos = (_bPosData select 0) select 1; 
                    } else {
                        _lowestPos = getPosATL _building;
                    };

                    {
                        if (alive _x && (getPosATL _x select 2) > 2.5) then {
                            _x doMove _lowestPos;
                            _x moveTo _lowestPos;
                            _needsDescent = true;
                        };
                    } forEach _squadAI;

                    if (_needsDescent) then {
                        private _descentTimeout = time + 30;
                        waitUntil {
                            sleep 2;
                            private _highUnits = {alive _x && (getPosATL _x select 2) > 2.5 && !unitReady _x} count _squadAI;
                            _highUnits == 0 || time > _descentTimeout || time - _searchStart > _maxTime
                        };
                    };

                    sleep 2; 
                } forEach _buildings;

                deleteMarkerLocal _marker;

                {
                    if (alive _x) then {
                        _x enableAI "AUTOCOMBAT";
                        _x enableAI "SUPPRESSION";
                        _x setUnitPos "AUTO";
                        _x setSpeedMode "NORMAL";
                        _x setBehaviour "AWARE";
                        doStop _x;
                        sleep 0.1;
                        _x doFollow _leader;
                    };
                } forEach _squadAI;
                
                ["QG : Bâtiments sécurisés. L'escouade se regroupe."] remoteExec ["systemChat", _leader];
            };
        },
        [],
        6.7,
        false,
        true,
        "",
        "alive _target && leader group _target == _target && ({!isPlayer _x && alive _x && vehicle _x == _x} count (units group _target) > 0) && (missionNamespace getVariable ['LL_Search_BuildingsNearby', false])"
    ];
};

[_fnc_addSearchAction] spawn {
    params ["_fnc_addSearchAction"];
    private _lastPlayer = objNull;
    while {true} do {
        waitUntil {sleep 1; player != _lastPlayer};
        _lastPlayer = player;
        if (!isNull _lastPlayer) then {
            [_lastPlayer] call _fnc_addSearchAction;
        };
    };
};
