params [
    ["_agent", objNull, [objNull]],
    ["_template", [], [[]]]
];

if (isNull _agent) exitWith { false };
if (!alive _agent) exitWith { false };
if (isPlayer _agent) exitWith { false };
if ((side _agent == independent || side _agent == resistance) && !(_agent getVariable ["LL_forceTemplate", false])) exitWith { false };
if (!local _agent) exitWith { false };
if (_agent getVariable ["MISSION_TemplateApplied", false]) exitWith { false };
if (count MISSION_CivilianTemplates == 0) exitWith { false };

_agent setVariable ["MISSION_TemplateApplied", true, true];

if (_template isEqualTo []) then {
    private _isFemaleUnit = "woman" in (toLower typeOf _agent);
    private _compatibleTemplates = MISSION_CivilianTemplates select { (_x select 2) == _isFemaleUnit };
    if (count _compatibleTemplates > 0) then {
        _template = selectRandom _compatibleTemplates;
    } else {
        _template = selectRandom MISSION_CivilianTemplates;
    };
};
_template params ["_class", "_loadout", "_isFemale", "_face", "_pitch"];

_agent setUnitLoadout _loadout;

private _agentSide = side _agent;
if (_agentSide == east || _agentSide == west || _agent getVariable ["LL_forceTemplate", false]) then {
    removeBackpack _agent;
    _agent addBackpack (selectRandom MISSION_BanditBackpacks);

    private _bLoadout = selectRandom MISSION_BanditLoadouts;
    _bLoadout params ["_priWep","_priMag","_priMagCount","_secWep","_secMag","_secMagCount","_smoke","_smokeCount","_FAK","_FAKCount"];

    if (_priWep != "") then {
        _agent addWeapon _priWep;
        for "_i" from 1 to _priMagCount do { _agent addMagazine _priMag };
        _agent addPrimaryWeaponItem (selectRandom ["CUP_acc_Flashlight","CUP_acc_Zenit_2DS"]);
    };
    if (_secWep != "") then {
        _agent addWeapon _secWep;
        for "_i" from 1 to _secMagCount do { _agent addMagazine _secMag };
        _agent addHandgunItem (selectRandom ["CUP_acc_CZ_M3X","acc_Flashlight_pistol"]);
    };
    for "_i" from 1 to _smokeCount do { _agent addMagazine _smoke };
    for "_i" from 1 to _FAKCount do { _agent addItem _FAK };
    _agent enableGunLights "forceOn";
} else {
    removeAllWeapons _agent;
};

if (!_isFemale) then {
    removeGoggles _agent;
    _agent addGoggles (selectRandom MISSION_CivilianBeards);
    removeHeadgear _agent;
    _agent addHeadgear (selectRandom MISSION_CivilianHats);
};

private _namesDB = if (_isFemale) then { MISSION_CivilianNames_Female } else { MISSION_CivilianNames_Male };
private _nameData = selectRandom _namesDB;
private _speaker = selectRandom ["Male01PER","Male02PER","Male03PER"];

[_agent, _nameData, _face, _speaker, _pitch] remoteExec ["LL_fnc_applyIdentity", 0, _agent];

if (!isNil "LL_fnc_setupUVO") then { [_agent] call LL_fnc_setupUVO; };

true
