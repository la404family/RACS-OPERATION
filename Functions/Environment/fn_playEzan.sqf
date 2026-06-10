params [["_minaretObj", objNull, [objNull]]];

if (!isNull _minaretObj) exitWith {
    if (hasInterface) then {
        _minaretObj say3D ["ezan", 2500, 1];
    };
};

if (!isServer) exitWith {};

private _soundRange = 2500;
private _soundRangeSqr = _soundRange ^ 2;

private _minarets = [];
for "_i" from 0 to 20 do {
    private _suffix  = if (_i < 10) then {format ["0%1", _i]} else {str _i};
    private _varName = format ["ezan_%1", _suffix];
    private _minaret = missionNamespace getVariable [_varName, objNull];
    
    if (!isNull _minaret) then {
        _minarets pushBack _minaret;
    };
};

if (_minarets isEqualTo []) exitWith {
    ["LL_fnc_playEzan: aucun objet minaret trouvé (ezan_00 … ezan_20)"] call BIS_fnc_error;
};

sleep (300 + random 600);

while {true} do {
    private _alivePlayers = allPlayers select { alive _x };
    
    {
        private _minaret = _x;
        private _nearbyPlayers = _alivePlayers select {
            (_x distanceSqr _minaret) < _soundRangeSqr
        };
        
        if (count _nearbyPlayers > 0) then {
            [_minaret] remoteExecCall ["LL_fnc_playEzan", _nearbyPlayers];
        };
        
    } forEach _minarets;

    sleep 1800;
};
