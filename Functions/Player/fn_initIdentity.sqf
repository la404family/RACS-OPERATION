if (!isServer) exitWith {};

addMissionEventHandler ["PlayerConnected", {
    params ["_id", "_uid", "_name", "_jip", "_owner", "_idstr"];
    [_owner] spawn {
        params ["_ownerId"];
        waitUntil { !isNil "LL_g_usedPlayerNames" };
        private _fnc_sendAllIdentities = {
            params ["_ownerId2"];
            for "_i" from 0 to 99 do {
                private _suffix = if (_i < 10) then { format ["0%1", _i] } else { str _i };
                private _unit = missionNamespace getVariable [format ["player_%1", _suffix], objNull];
                if (!isNull _unit) then {
                    private _identity = _unit getVariable ["LL_s_identity", []];
                    if (count _identity >= 5) then {
                        _identity params ["_nameData", "_faceType", "_face", "_speaker", "_pitch", ["_beard", "", [""]]];
                        [_unit, _nameData, _face, _speaker, _pitch, _beard] remoteExec ["LL_fnc_applyIdentity", _ownerId2];
                    };
                };
            };
        };
        sleep 5;
        [_ownerId] call _fnc_sendAllIdentities;
        sleep 25;
        [_ownerId] call _fnc_sendAllIdentities;
    };
}];

private _names_african = [
    ["Moussa Diallo", "Moussa", "Diallo"], ["Mamadou Traoré", "Mamadou", "Traoré"], ["Ibrahim Keita", "Ibrahim", "Keita"],
    ["Sekou Diop", "Sekou", "Diop"], ["Ousmane Sy", "Ousmane", "Sy"], ["Bakary Sow", "Bakary", "Sow"], ["Ismaël Koné", "Ismaël", "Koné"]
];

private _names_arab = [
    ["Mehdi Benali", "Mehdi", "Benali"], ["Sofiane Haddad", "Sofiane", "Haddad"], ["Karim Mansouri", "Karim", "Mansouri"],
    ["Mohamed Trabelsi", "Mohamed", "Trabelsi"], ["Walid Belkacem", "Walid", "Belkacem"], ["Hicham Bouzid", "Hicham", "Bouzid"],
    ["Adel Gharbi", "Adel", "Gharbi"], ["Nassim Saïdi", "Nassim", "Saïdi"], ["Rachid Ziani", "Rachid", "Ziani"],
    ["Adam Khayat", "Adam", "Khayat"], ["Rayane Meriah", "Rayane", "Meriah"]
];

private _names_asian = [
    ["Minh Tuan Nguyen", "Minh Tuan", "Nguyen"], ["Kevin Chang", "Kevin", "Chang"], ["Thomas Vo", "Thomas", "Vo"],
    ["Nicolas Hoang", "Nicolas", "Hoang"], ["Pierre Dang", "Pierre", "Dang"], ["Jun Li", "Jun", "Li"],
    ["Hao Wang", "Hao", "Wang"], ["Kenji Sato", "Kenji", "Sato"], ["Jun-ho Kang", "Jun-ho", "Kang"],
    ["Si-woo Cho", "Si-woo", "Cho"], ["Yer Xiong", "Yer", "Xiong"]
];

private _names_pacific = [
    ["Teiva Tehuiotoa", "Teiva", "Tehuiotoa"], ["Manaarii Puarai", "Manaarii", "Puarai"], ["Teva Rohi", "Teva", "Rohi"],
    ["Manua Tuihani", "Manua", "Tuihani"], ["Keanu Loa", "Keanu", "Loa"], ["Tamatoa Arii", "Tamatoa", "Arii"],
    ["Ariitea Tehei", "Ariitea", "Tehei"]
];

private _names_standard = [
    ["Julien Martin", "Julien", "Martin"], ["Thomas Bernard", "Thomas", "Bernard"], ["Nicolas Petit", "Nicolas", "Petit"],
    ["Alexandre Dubois", "Alexandre", "Dubois"], ["Maxime Moreau", "Maxime", "Moreau"], ["Guillaume Laurent","Guillaume", "Laurent"],
    ["Lucas Girard", "Lucas", "Girard"], ["Romain Roux", "Romain", "Roux"], ["Clément Fournier", "Clément", "Fournier"],
    ["Mathieu Bonnet", "Mathieu", "Bonnet"], ["Erwan Le Gall", "Erwan", "Le Gall"], ["Enzo Rossi", "Enzo", "Rossi"]
];

private _allNamesTyped = [];
{ _allNamesTyped pushBack [_x, "Black"]; } forEach _names_african;
{ _allNamesTyped pushBack [_x, "Arab"]; } forEach _names_arab;
{ _allNamesTyped pushBack [_x, "Asian"]; } forEach _names_asian;
{ _allNamesTyped pushBack [_x, "Pacific"]; } forEach _names_pacific;
{ _allNamesTyped pushBack [_x, "White"]; } forEach _names_standard;

LL_g_allNamesTyped = _allNamesTyped;
LL_g_usedPlayerNames = [];

private _unitRoles = [];
for "_i" from 0 to 99 do {
    private _suffix = if (_i < 10) then { format ["0%1", _i] } else { str _i };
    private _varName = format ["player_%1", _suffix];
    private _unit = missionNamespace getVariable [_varName, objNull];
    if (!isNull _unit) then {
        private _rank = "PRIVATE";
        if (_varName == "player_00") then { _rank = "CORPORAL"; };
        if (_varName == "player_01") then { _rank = "SERGEANT"; };
        _unitRoles pushBack [_varName, _rank];
    };
};

private _fnc_processUnit = {
    params ["_unit", "_pool", "_roles"];
    private _available = _pool select { !((_x select 0 select 0) in LL_g_usedPlayerNames) };
    if (_available isEqualTo []) then { LL_g_usedPlayerNames = []; _available = _pool; };
    private _entry = selectRandom _available;
    private _nameData = _entry select 0;
    private _faceType = _entry select 1;
    LL_g_usedPlayerNames pushBack (_nameData select 0);

    private _faces = switch (_faceType) do {
        case "Black": { ["AfricanHead_01","AfricanHead_02","AfricanHead_03"] };
        case "Arab": { ["PersianHead_A3_01","PersianHead_A3_02","PersianHead_A3_03","GreekHead_A3_01","GreekHead_A3_02","GreekHead_A3_03","GreekHead_A3_04","GreekHead_A3_05","GreekHead_A3_06"] };
        case "Asian": { ["AsianHead_A3_01","AsianHead_A3_02","AsianHead_A3_03"] };
        case "Pacific": { ["TanoanHead_A3_01","TanoanHead_A3_02","TanoanHead_A3_03","TanoanHead_A3_04","TanoanHead_A3_05"] };
        default { ["WhiteHead_01","WhiteHead_02","WhiteHead_03","WhiteHead_04","WhiteHead_05","WhiteHead_06","WhiteHead_07","WhiteHead_08","WhiteHead_09","WhiteHead_10","WhiteHead_11","WhiteHead_12","WhiteHead_13","WhiteHead_14","WhiteHead_15","WhiteHead_16","WhiteHead_17","WhiteHead_18","WhiteHead_19","WhiteHead_20","WhiteHead_21"] };
    };
    private _face = selectRandom _faces;

    private _speaker = switch (_faceType) do {
        case "White": { selectRandom ["Male01ENG", "Male02ENG", "Male03ENG", "Male04ENG"] };
        case "Black": { selectRandom ["Male05ENG", "Male06ENG", "Male07ENG"] };
        default { selectRandom ["Male08ENG", "Male09ENG", "Male10ENG", "Male11ENG", "Male12ENG"] };
    };
    private _pitch = 0.90 + random 0.20;

    {
        if ((missionNamespace getVariable [_x select 0, objNull]) isEqualTo _unit) exitWith {
            _unit setUnitRank (_x select 1);
        };
    } forEach _roles;

    private _beard = "";

    [_unit, _nameData, _face, _speaker, _pitch, _beard] remoteExec ["LL_fnc_applyIdentity", 0, _unit];

    _unit setVariable ["LL_s_identity", [_nameData, _faceType, _face, _speaker, _pitch, _beard], true];
    _unit setVariable ["LL_IdentitySet", true, true];

    if (!isNil "LL_fnc_setupUVO") then { [_unit] call LL_fnc_setupUVO; };
};

private _endTime = time + 300;
while { time < _endTime } do {
    private _unprocessed = _unitRoles select {
        private _u = missionNamespace getVariable [_x select 0, objNull];
        !isNull _u && alive _u && !(_u getVariable ["LL_IdentitySet", false])
    };
    if (_unprocessed isEqualTo []) exitWith {};
    {
        private _unit = missionNamespace getVariable [_x select 0, objNull];
        if (!isNull _unit) then {
            [_unit, _allNamesTyped, _unitRoles] call _fnc_processUnit;
        };
    } forEach _unprocessed;

    private _remaining = _unitRoles select {
        private _u = missionNamespace getVariable [_x select 0, objNull];
        !isNull _u && alive _u && !(_u getVariable ["LL_IdentitySet", false])
    };
    if (_remaining isEqualTo []) exitWith {};
    sleep 2;
};

[_unitRoles] spawn {
    params ["_roles"];
    sleep 60;
    {
        private _unit = missionNamespace getVariable [_x select 0, objNull];
        if (!isNull _unit) then {
            private _identity = _unit getVariable ["LL_s_identity", []];
            if (count _identity >= 5) then {
                _identity params ["_nameData", "_faceType", "_face", "_speaker", "_pitch", ["_beard", "", [""]]];
                [_unit, _nameData, _face, _speaker, _pitch, _beard] remoteExec ["LL_fnc_applyIdentity", 0];
            };
        };
    } forEach _roles;
};
