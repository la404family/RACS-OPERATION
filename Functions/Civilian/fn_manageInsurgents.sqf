if (!isServer) exitWith {};

private _INTERVAL_MIN  = 100;
private _INTERVAL_MAX  = 400;
private _DIST_MIN      = 300;    
private _DIST_MAX      = 450;    
private _REQ_COUNT     = 3;      

waitUntil { !isNil "LL_s_civSpawned" };
sleep 15;

private _fnc_equipBandit = {
    params ["_unit"];

    if (!isNil "MISSION_BanditBackpacks") then {
        removeBackpack _unit;
        _unit addBackpack (selectRandom MISSION_BanditBackpacks);
    };

    if (!isNil "MISSION_BanditLoadouts") then {
        private _bLoadout = selectRandom MISSION_BanditLoadouts;
        _bLoadout params ["_priWep","_priMag","_priMagCount","_secWep","_secMag","_secMagCount","_smoke","_smokeCount","_FAK","_FAKCount"];

        if (_priWep != "") then {
            _unit addWeapon _priWep;
            for "_i" from 1 to _priMagCount do { _unit addMagazine _priMag };
            _unit addPrimaryWeaponItem (selectRandom ["CUP_acc_Flashlight","CUP_acc_Zenit_2DS"]);
        };
        if (_secWep != "") then {
            _unit addWeapon _secWep;
            for "_i" from 1 to _secMagCount do { _unit addMagazine _secMag };
            _unit addHandgunItem (selectRandom ["CUP_acc_CZ_M3X","acc_Flashlight_pistol"]);
        };
        for "_i" from 1 to _smokeCount do { _unit addMagazine _smoke };
        for "_i" from 1 to _FAKCount do { _unit addItem _FAK };
        _unit enableGunLights "forceOn";
    };

    _unit linkItem "ItemMap";
    _unit linkItem "ItemCompass";
    _unit linkItem "ItemRadio";
};

while {true} do {

    sleep (_INTERVAL_MIN + random (_INTERVAL_MAX - _INTERVAL_MIN));

    private _players = allPlayers select { alive _x && !(_x isKindOf "HeadlessClient_F") };
    if (count _players == 0) then { continue; };

    private _refPlayer = selectRandom _players;

    LL_s_civSpawned = LL_s_civSpawned select { !isNull _x && alive _x };

    private _eligibleCivs = LL_s_civSpawned select {
        private _civ = _x;
        private _nearAnyPlayer = false;
        {
            private _dist = _civ distance2D _x;
            if (_dist >= _DIST_MIN && _dist <= _DIST_MAX) exitWith { _nearAnyPlayer = true; };
        } forEach _players;
        _nearAnyPlayer && !(_civ getVariable ["LL_isInsurgent", false])
    };

    if (count _eligibleCivs >= _REQ_COUNT) then {

        private _shuffled = _eligibleCivs call BIS_fnc_arrayShuffle;
        private _selected = [_shuffled select 0, _shuffled select 1, _shuffled select 2];

        private _insurgentGrp = createGroup [east, true];

        {
            private _civ = _x;

            [_civ] joinSilent _insurgentGrp;

            [_civ] call _fnc_equipBandit;

            _civ setVariable ["LL_isInsurgent", true, true];
            _civ setCombatMode "RED";
            _civ setBehaviour "COMBAT";
            _civ setSkill 0.5;
            _civ enableAI "ALL";

        } forEach _selected;

        private _grpCenter = [0,0,0];
        { _grpCenter = _grpCenter vectorAdd (getPosATL _x); } forEach _selected;
        _grpCenter = _grpCenter vectorMultiply (1 / count _selected);

        private _nearestPlayer = _players select [{ _x distance2D _grpCenter }, "ASCEND"] select 0;
        private _targetPos = getPosATL _nearestPlayer;

        private _wp = _insurgentGrp addWaypoint [_targetPos, 50];
        _wp setWaypointType "SAD";
        _wp setWaypointBehaviour "COMBAT";
        _wp setWaypointCombatMode "RED";
        _wp setWaypointSpeed "FULL";

        { _insurgentGrp reveal [_x, 4]; } forEach _players;

        (leader _insurgentGrp) commandMove _targetPos;
    };
};
