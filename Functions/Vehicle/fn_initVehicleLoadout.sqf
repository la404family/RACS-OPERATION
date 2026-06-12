params [
    ["_veh", objNull, [objNull]]
];

if (isNull _veh) then {
    _veh = missionNamespace getVariable ["vehicule_team", objNull];
};
if (isNull _veh) exitWith {};

if (!isServer) exitWith {};

// Vider le vehicule
clearWeaponCargoGlobal _veh;
clearMagazineCargoGlobal _veh;
clearItemCargoGlobal _veh;
clearBackpackCargoGlobal _veh;

private _weaponsMap = createHashMap;

private _units = [];
for "_i" from 0 to 99 do {
    private _s = if (_i < 10) then { format ["0%1", _i] } else { str _i };
    private _u = missionNamespace getVariable [format ["player_%1", _s], objNull];
    if (!isNull _u && alive _u) then { _units pushBack _u; };
};

{
    private _weaponsToCheck = [];
    if (primaryWeapon _x != "") then { _weaponsToCheck pushBack [primaryWeapon _x, primaryWeaponMagazine _x] };
    if (secondaryWeapon _x != "") then { _weaponsToCheck pushBack [secondaryWeapon _x, secondaryWeaponMagazine _x] };

    {
        _x params ["_w", "_mArray"];
        if (!(_w in _weaponsMap)) then {
            private _mag = "";
            if (count _mArray > 0) then { _mag = _mArray select 0; } else {
                private _c2 = [_w] call BIS_fnc_compatibleMagazines;
                if (count _c2 > 0) then { _mag = _c2 select 0; };
            };
            if (_mag != "") then {
                _weaponsMap set [_w, _mag];
            };
        };
    } forEach _weaponsToCheck;
} forEach _units;

// Ajouter au vehicule
{
    private _weapon = _x;
    private _mag = _y;
    _veh addWeaponCargoGlobal [_weapon, 2];
    _veh addMagazineCargoGlobal [_mag, 2];
} forEach _weaponsMap;

_veh addItemCargoGlobal ["FirstAidKit", 6];
_veh addMagazineCargoGlobal ["HandGrenade", 4];
_veh addMagazineCargoGlobal ["SmokeShell", 4];
