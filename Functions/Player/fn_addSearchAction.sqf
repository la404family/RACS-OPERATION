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
        localize "STR_LL_SearchAction_Title",
        {
            params ["_target", "_caller", "_actionId", "_arguments"];

            private _center = getPosATL _caller;
            private _buildings = nearestObjects [_center, ["House", "Building"], 50];
            _buildings = _buildings select { count (_x buildingPos -1) > 1 };

            if (_buildings isEqualTo []) exitWith { ["STR_LL_SearchAction_NoBuildings", [], 6, false] call LL_fnc_radioMessage; };

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
                ["STR_LL_SearchAction_NoAI", [], 6, false] call LL_fnc_radioMessage;
            };

            [_caller, "gestureAdvance"] remoteExec ["playActionNow", 0];

            [_buildings, _squadAI, _caller, _marker] spawn {
                params ["_buildings", "_squadAI", "_leader", "_marker"];

                private _allPositions = [];
                {
                    private _bPos = _x buildingPos -1;
                    if (_bPos isNotEqualTo []) then {
                        _allPositions append _bPos;
                    };
                } forEach _buildings;

                if (_allPositions isEqualTo []) exitWith {
                    deleteMarkerLocal _marker;
                    ["STR_LL_SearchAction_Secured", [], 6, false] remoteExec ["LL_fnc_radioMessage", _leader];
                };

                private _posData = _allPositions apply { [- (_x select 2), _x] };
                _posData sort true;
                _allPositions = _posData apply { _x select 1 };

                private _assignedPositions = [];
                private _searchStart = time;

                {
                    private _unit = _x;
                    if (!alive _unit) then {continue};

                    private _targetPos = [];
                    private _posIndex = -1;
                    {
                        private _candidate = _x;
                        private _tooClose = false;
                        {
                            if (_candidate distance _x < 4) exitWith { _tooClose = true; };
                        } forEach _assignedPositions;
                        
                        if (!_tooClose) exitWith {
                            _targetPos = _candidate;
                            _posIndex = _forEachIndex;
                        };
                    } forEach _allPositions;

                    if (_targetPos isEqualTo []) then {
                        if (_allPositions isNotEqualTo []) then {
                            _targetPos = _allPositions select 0;
                            _posIndex = 0;
                        } else {
                            private _b = selectRandom _buildings;
                            _targetPos = _b getRelPos [8 + random 7, random 360];
                        };
                    };

                    if (_posIndex != -1) then {
                        _allPositions deleteAt _posIndex;
                    };
                    _assignedPositions pushBack _targetPos;

                    _unit setVariable ["LL_IsSearching", true];

                    _unit disableAI "AUTOCOMBAT";
                    _unit disableAI "SUPPRESSION";
                    _unit setUnitPos "UP";
                    _unit setBehaviour "AWARE";
                    _unit setSpeedMode "FULL";
                    _unit setCombatMode "YELLOW";

                    _unit doMove _targetPos;
                    _unit moveTo _targetPos;

                    [_unit, _targetPos, _leader] spawn {
                        params ["_unit", "_targetPos", "_leader"];
                        private _startTime = time;
                        private _lastPos = getPosATL _unit;
                        private _stuckCount = 0;
                        private _maxTime = 180;

                        while {alive _unit && time - _startTime < _maxTime} do {
                            sleep 2.5;

                            if (currentCommand _unit == "STOP" || currentCommand _unit == "FOLLOW") exitWith {};

                            private _dist = _unit distance _targetPos;

                            if (_dist < 2.5 || unitReady _unit) exitWith {
                                doStop _unit;
                                _unit setUnitPos "UP";
                                for "_k" from 1 to 2 do {
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

                        if (alive _unit) then {
                            _unit enableAI "AUTOCOMBAT";
                            _unit enableAI "SUPPRESSION";
                            _unit setUnitPos "AUTO";
                            _unit setSpeedMode "NORMAL";
                            _unit setBehaviour "AWARE";
                            doStop _unit;
                            sleep 0.1;
                            _unit doFollow _leader;
                        };
                        _unit setVariable ["LL_IsSearching", false];
                    };

                    sleep 0.5;
                } forEach _squadAI;

                private _timeout = time + 200;
                waitUntil {
                    sleep 3;
                    private _active = {alive _x && _x getVariable ["LL_IsSearching", false]} count _squadAI;
                    _active == 0 || time > _timeout
                };

                deleteMarkerLocal _marker;
                ["STR_LL_SearchAction_Secured", [], 6, false] remoteExec ["LL_fnc_radioMessage", _leader];
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
