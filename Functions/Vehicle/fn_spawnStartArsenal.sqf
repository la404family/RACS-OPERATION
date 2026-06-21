if (!isServer) exitWith {};

[] spawn {

    private _lzPos = [0,0,0];
    waitUntil {
        sleep 0.5;
        _lzPos = missionNamespace getVariable ["MISSION_intro_lz", [0,0,0]];
        _lzPos isNotEqualTo [0,0,0]
    };

    private _veh = missionNamespace getVariable ["vehicule_team", objNull];
    waitUntil {
        sleep 0.5;
        !isNull _veh && { _veh distance2D _lzPos < 100 }
    };

    sleep 1;

    private _pos = _veh modelToWorld [2.5, 4.5, 0];
    _pos set [2, 0]; 

    private _crate = createVehicle ["B_supplyCrate_F", _pos, [], 0, "CAN_COLLIDE"];
    _crate setDir (getDir _veh);
    _crate setPos _pos;

    clearWeaponCargoGlobal _crate;
    clearMagazineCargoGlobal _crate;
    clearItemCargoGlobal _crate;
    clearBackpackCargoGlobal _crate;

    private _allWeapons = [];
    private _cfgWeapons = configFile >> "CfgWeapons";

    {
        private _weaponName = configName _x;
        private _scope = getNumber (_x >> "scope");
        private _type = getNumber (_x >> "type");
        if (_scope == 2 && { _type in [1, 2, 4] }) then {
            _allWeapons pushBack _weaponName;
        };
    } forEach ("true" configClasses _cfgWeapons);

    ["AmmoboxInit", [_crate, false]] call BIS_fnc_arsenal;
    [_crate, _allWeapons, true] call BIS_fnc_addVirtualWeaponCargo;

    private _mkrName = "mkr_start_arsenal";
    createMarker [_mkrName, _pos];
    _mkrName setMarkerType "mil_box";
    _mkrName setMarkerColor "ColorYellow";

    private _introSmoke = "SmokeShellRed" createVehicle _pos;
    _introSmoke attachTo [_crate, [0, 0, 0.4]];

    [_crate, _pos] spawn {
        params ["_crate", "_pos"];
        waitUntil {
            sleep 0.5;
            missionNamespace getVariable ["MISSION_intro_finished", false]
        };
        if (!isNull _crate) then {
            private _startSmoke = "SmokeShellRed" createVehicle _pos;
            _startSmoke attachTo [_crate, [0, 0, 0.4]];
        };
    };

    private _duration = 1200;
    private _endTime = time + _duration;

    while { time < _endTime && !isNull _crate } do {
        private _timeLeft = round (_endTime - time);
        if (_timeLeft < 0) then { _timeLeft = 0; };
        private _mins = floor (_timeLeft / 60);
        private _secs = _timeLeft mod 60;

        private _timeStr = format ["%1:%2", if (_mins < 10) then {"0"+str _mins} else {str _mins}, if (_secs < 10) then {"0"+str _secs} else {str _secs}];

        private _localizedText = localize "STR_LL_StartArsenal_Marker";
        if (_localizedText == "" || _localizedText == "STR_LL_StartArsenal_Marker") then {
            _localizedText = "PREPARATIFS (Arsenal)";
        };
        private _mkrText = format ["%1 - %2", _localizedText, _timeStr];

        _mkrName setMarkerText _mkrText;
        sleep 1;
    };

    deleteMarker _mkrName;

    if (!isNull _crate) then {
        private _cratePos = getPosATL _crate;

        [[_cratePos], {
            params ["_pos"];
            [_pos] spawn {
                params ["_pos"];
                private _emitter = "#particlesource" createVehicleLocal _pos;
                _emitter setParticleCircle [0.1, [0.1, 0.1, 0]];
                _emitter setParticleRandom [2, [0.4, 0.4, 0.2], [0.5, 0.5, 0.3], 1, 0.2, [0, 0, 0, 0.05], 0, 0];
                _emitter setParticleParams [
                    ["\A3\data_f\ParticleEffects\Universal\Universal", 16, 7, 48, 1], "", "Billboard",
                    1, 8, [0, 0, 0.1], [0, 0, 0.4], 0, 1.27, 1, 0.05,
                    [1, 3.5, 6.5], 
                    [[0.9, 0.9, 0.9, 0.85], [0.95, 0.95, 0.95, 0.55], [0.95, 0.95, 0.95, 0]],
                    [0.5], 0.1, 0, "", "", _emitter
                ];
                _emitter setDropInterval 0.005; 
                sleep 2; 
                deleteVehicle _emitter;
            };
        }] remoteExec ["spawn", 0];

        sleep 1; 

        ["AmmoboxExit", [_crate]] call BIS_fnc_arsenal;
        deleteVehicle _crate;
    };
};
