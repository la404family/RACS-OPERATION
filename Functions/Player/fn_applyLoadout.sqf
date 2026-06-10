params [
    ["_unit", objNull, [objNull]],
    ["_data", [], [[]]]
];

if (isNull _unit || !alive _unit || !local _unit) exitWith {};

_data params [
    ["_u", "", [""]],
    ["_v", "", [""]],
    ["_b", "", [""]],
    ["_h", "", [""]],
    ["_c", "", [""]]
];

private _pWeapon = primaryWeapon _unit;
private _hWeapon = handgunWeapon _unit;
private _sWeapon = secondaryWeapon _unit;

private _pMag = "";
if (_pWeapon != "") then {
    private _m = primaryWeaponMagazine _unit;
    if (count _m > 0) then { _pMag = _m select 0; } else {
        private _c2 = [_pWeapon] call BIS_fnc_compatibleMagazines;
        if (count _c2 > 0) then { _pMag = _c2 select 0; };
    };
    if (_pMag == "" && {toLower _pWeapon find "m249" != -1 || toLower _pWeapon find "lmg" != -1}) then {
        _pMag = "CUP_200Rnd_TE4_Red_Tracer_556x45_M249";
    };
};

private _hMag = "";
if (_hWeapon != "") then {
    private _m = handgunMagazine _unit;
    if (count _m > 0) then { _hMag = _m select 0; } else {
        private _c2 = [_hWeapon] call BIS_fnc_compatibleMagazines;
        if (count _c2 > 0) then { _hMag = _c2 select 0; };
    };
};

private _pItems = primaryWeaponItems _unit;
private _hItems = handgunItems _unit;

removeAllWeapons _unit;
removeAllItems _unit;
removeAllAssignedItems _unit;
removeUniform _unit;
removeVest _unit;
removeBackpack _unit;
removeHeadgear _unit;
removeGoggles _unit;

_unit forceAddUniform _u;
_unit addVest _v;
_unit addBackpack _b;
_unit addHeadgear _h;
_unit addGoggles _c;

if (_pMag != "") then { for "_i" from 1 to 5 do { _unit addMagazine _pMag; }; };
if (_hMag != "") then { for "_i" from 1 to 3 do { _unit addMagazine _hMag; }; };

for "_i" from 1 to 2 do { _unit addMagazine "HandGrenade"; };
for "_i" from 1 to 2 do { _unit addMagazine "SmokeShell"; };
for "_i" from 1 to 3 do { _unit addItem "FirstAidKit"; };

if (_pWeapon != "") then {
    _unit addWeapon _pWeapon;
    { if (_x != "") then { _unit addPrimaryWeaponItem _x; }; } forEach _pItems;
};
if (_hWeapon != "") then {
    _unit addWeapon _hWeapon;
    { if (_x != "") then { _unit addHandgunItem _x; }; } forEach _hItems;
};
if (_sWeapon != "") then { _unit addWeapon _sWeapon; };

_unit addWeapon "CUP_LRTV";
_unit linkItem "ItemMap";
_unit linkItem "ItemCompass";
_unit linkItem "ItemWatch";
_unit linkItem "ItemRadio";
_unit linkItem "NVGogglesB_blk_F";

if (_pWeapon != "") then { _unit selectWeapon _pWeapon; };
[_unit, "CSAT_ScimitarRegiment"] call BIS_fnc_setUnitInsignia;
_unit setVariable ["LL_LoadoutSet", true, true];
