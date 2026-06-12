#define DEBUG_MODE (missionNamespace getVariable ["DEBUG_MODE", true])

if (hasInterface) then {
    if (missionNamespace getVariable ["MISSION_intro_cl", false]) exitWith {};
    missionNamespace setVariable ["MISSION_intro_cl", true];

    [] spawn {
        waitUntil { time > 0.1 };

        disableSerialization;

        cutText ["", "BLACK FADED", 999];
        0 fadeSound 0;
        showCinemaBorder true;
        disableUserInput true;

        waitUntil { !isNull player };
        player allowDamage false;

        [] spawn {
            sleep 100;
            disableUserInput false;
            disableUserInput true;
            disableUserInput false;
            player allowDamage true;
            showCinemaBorder false;
        };

        sleep 10;

        private _ppColor = ppEffectCreate ["ColorCorrections", 1500];
        _ppColor ppEffectEnable true;
        _ppColor ppEffectAdjust [
            1,
            0.95,
            0.05,
            [0.15, 0.15, 0.2, 0.0],
            [0.85, 0.85, 0.9, 0.6],
            [0.1, 0.1, 0.15, 0]
        ];
        _ppColor ppEffectCommit 0;

        private _ppGrain = ppEffectCreate ["FilmGrain", 2005];
        _ppGrain ppEffectEnable true;
        _ppGrain ppEffectAdjust [0.08, 0.9, 1, 0.08, 1, false];
        _ppGrain ppEffectCommit 0;

        waitUntil { !isNil "MISSION_intro_lz" };
        private _lzPos = MISSION_intro_lz;

        private _buildingTargets = [];
        for "_i" from 0 to 99 do {
            private _s = str _i;
            while { count _s < 3 } do { _s = "0" + _s };
            private _varName = format ["M_Dans_Bat_%1", _s];
            private _obj = missionNamespace getVariable [_varName, objNull];
            if (!isNull _obj) then { _buildingTargets pushBack _obj; };
        };
        if (count _buildingTargets == 0) then { _buildingTargets = [vehicule_team]; };

        0 fadeMusic 1;
        playMusic "Music_Intro";
        3 fadeSound 1;

        private _tgt1 = selectRandom _buildingTargets;
        private _pool2 = _buildingTargets - [_tgt1];
        private _tgt2 = if (count _pool2 > 0) then { selectRandom _pool2 } else { _tgt1 };

        private _pos1 = getPos _tgt1;
        private _pos2 = getPos _tgt2;

        private _ang1 = random 360;
        private _ang2 = random 360;
        private _dist1 = 140 + (random 90);
        private _dist2 = 100 + (random 80);
        private _h1 = 110 + (random 60);
        private _h2 = 90  + (random 60);

        private _camStartX = (_pos1 select 0) + _dist1 * sin _ang1;
        private _camStartY = (_pos1 select 1) + _dist1 * cos _ang1;
        private _camStartZ = (_pos1 select 2) + _h1;

        private _cam = "camera" camCreate [_camStartX, _camStartY, _camStartZ];
        _cam cameraEffect ["INTERNAL", "BACK"];

        _cam camSetPos [_camStartX, _camStartY, _camStartZ];
        _cam camSetTarget _tgt1;
        _cam camSetFov 0.50 + (random 0.15);
        _cam camCommit 0;
        waitUntil { camCommitted _cam };

        cutText ["", "BLACK IN", 2.5];

        _cam camSetPos [
            (_pos2 select 0) + _dist2 * sin _ang2,
            (_pos2 select 1) + _dist2 * cos _ang2,
            (_pos2 select 2) + _h2
        ];
        _cam camSetTarget _tgt2;
        _cam camCommit 15;

        sleep 3;  

        titleText [
            format [
                "<t size='2.2' color='#e0e0e0' font='PuristaBold' shadow='2' align='center'>%1</t><br/>" +
                "<t size='1.0' color='#909090' font='PuristaLight' align='center' letterSpacing='0.15'>%2</t>",
                toUpper (localize "STR_LL_Intro_Author"),
                localize "STR_LL_Intro_Presents"
            ],
            "PLAIN", 1, true, true
        ];
        sleep 4;
        titleText ["", "PLAIN", 0.5];
        sleep 0.5;

        titleText [
            format [
                "<t size='2.6' color='#ffffff' font='PuristaBold' shadow='2' align='center'>%1</t>",
                localize "STR_LL_Intro_Title"
            ],
            "PLAIN", 1, true, true
        ];
        sleep 4;
        titleText ["", "PLAIN", 0.5];

        cutText ["", "BLACK FADED", 1];
        sleep 1.5;

        private _p2h = date select 3;
        private _p2m = date select 4;
        private _p2time = format ["%1:%2",
            if (_p2h < 10) then {"0" + str _p2h} else {str _p2h},
            if (_p2m < 10) then {"0" + str _p2m} else {str _p2m}
        ];

        private _p2chars1 = toArray (localize "STR_LL_Intro_Location");
        private _p2chars2 = toArray (" - " + _p2time);
        private _p2built  = "";

        _p2built = "";

        {
            _p2built = _p2built + toString [_x];

            [
                format ["<t size='1.3' color='#ffffff' font='PuristaLight' align='center' shadow='2'>%1</t>", _p2built],
                -1,              
                0.35,            
                5,               
                0,               
                0,               
                793              
            ] spawn BIS_fnc_dynamicText;

            if (_x != 32) then {
                playSound "readoutClick";
            };
            sleep 0.08;
        } forEach _p2chars1;

        {
            _p2built = _p2built + toString [_x];

            [
                format ["<t size='1.3' color='#ffffff' font='PuristaLight' align='center' shadow='2'>%1</t>", _p2built],
                -1,              
                0.35,            
                5,               
                0,               
                0,               
                793              
            ] spawn BIS_fnc_dynamicText;

            if (_x != 32) then {
                playSound "readoutClick";
            };
            sleep 0.12;
        } forEach _p2chars2;

        sleep 2.5;
        ["", -1, 0.35, 1, 0.5, 0, 793] spawn BIS_fnc_dynamicText;

        waitUntil { !isNil "MISSION_intro_heli" && { !isNull MISSION_intro_heli } };
        private _camHeli = MISSION_intro_heli;

        if (isNull _camHeli) exitWith {
            _cam cameraEffect ["TERMINATE", "BACK"]; camDestroy _cam;
            ppEffectDestroy _ppColor; ppEffectDestroy _ppGrain;
            showCinemaBorder false; player allowDamage true;
            disableUserInput false; disableUserInput true; disableUserInput false;
            cutText ["", "BLACK IN", 2];
            missionNamespace setVariable ["MISSION_intro_finished", true, true];
        };

        _ppColor ppEffectAdjust [0.9, 0.85, 0.1, [0.3, 0.3, 0.35, 0.15], [0.65, 0.65, 0.75, 0.5], [0.15, 0.15, 0.25, 0.1]];
        _ppColor ppEffectCommit 1.5;
        _ppGrain ppEffectAdjust [0.18, 1.3, 1.2, 0.18, 1.2, false];
        _ppGrain ppEffectCommit 1.5;

        detach _cam;
        cutText ["", "BLACK FADED", 0.8];
        sleep 0.8;
        cutText ["", "BLACK IN", 1.2];

        _cam attachTo [_camHeli, [0, 1.1, 0.1]];
        _cam setVectorDirAndUp [[0, 1, 0], [0, 0, 1]];
        _cam camSetFov 0.80;
        _cam camCommit 0;

        sleep 15;  

        detach _cam;
        cutText ["", "BLACK FADED", 0.5];
        sleep 0.5;
        cutText ["", "BLACK IN", 1];

        _ppColor ppEffectAdjust [1, 1.0, -0.05, [0.15, 0.15, 0.2, 0.0], [0.85, 0.85, 0.9, 0.65], [0.1, 0.1, 0.15, 0]];
        _ppColor ppEffectCommit 1;
        _ppGrain ppEffectAdjust [0.04, 0.7, 0.8, 0.04, 0.8, false];
        _ppGrain ppEffectCommit 1;

        private _orbStartTime = time;
        private _orbDuration  = 14;

        while { time < _orbStartTime + _orbDuration } do {
            private _progress   = (time - _orbStartTime) / _orbDuration;
            private _angle      = -90 + (_progress * 150);   
            private _distance   = 35 - (_progress * 13);     
            private _heliPos    = getPosATL _camHeli;
            private _finalAngle = (getDir _camHeli) + _angle;

            _cam camSetPos [
                (_heliPos select 0) + (sin _finalAngle * _distance),
                (_heliPos select 1) + (cos _finalAngle * _distance),
                (_heliPos select 2) + 10
            ];
            _cam camSetTarget _camHeli;
            _cam camSetFov (0.80 - (_progress * 0.15));  
            _cam camCommit 0.4;
            sleep 0.1;
        };

        detach _cam;
        cutText ["", "BLACK FADED", 0.5];
        sleep 0.5;

        _cam camSetPos [
            (_lzPos select 0) + 30,
            (_lzPos select 1) - 80,
            (_lzPos select 2) + 40
        ];
        _cam camSetTarget _lzPos;
        _cam camSetFov 0.50;
        _cam camCommit 0;
        waitUntil { camCommitted _cam };

        cutText ["", "BLACK IN", 1];

        private _plan5Start = time;
        while { !isTouchingGround _camHeli && { (getPosATL _camHeli select 2) > 1 } } do {
            private _prog = ((time - _plan5Start) / 12) min 1;
            _cam camSetPos [
                (_lzPos select 0) + 30 + (sin (time * 0.8) * 8),
                (_lzPos select 1) - 80 + (cos (time * 0.8) * 8),
                (_lzPos select 2) + 40 - (_prog * 28)
            ];
            _cam camSetFov (0.50 + (_prog * 0.12));
            _cam camCommit 0.4;
            sleep 0.2;
        };

        cutText ["", "BLACK FADED", 0];

        waitUntil { vehicle player == player };
        sleep 1;

        sleep 1;

        _cam cameraEffect ["TERMINATE", "BACK"];
        camDestroy _cam;
        ppEffectDestroy _ppColor;
        ppEffectDestroy _ppGrain;

        player switchCamera "INTERNAL";
        showCinemaBorder false;
        player allowDamage true;

        disableUserInput false;
        disableUserInput true;
        disableUserInput false;

        cutText ["", "BLACK IN", 3];

        [
            format [
                "<t size='1.0' color='#bbbbbb' font='PuristaLight' align='center'>%2</t>",
                localize "STR_LL_Intro_MissionStartSubtitle"
            ],
            -1, -1, 5, 1, 0, 793
        ] spawn BIS_fnc_dynamicText;

        missionNamespace setVariable ["MISSION_intro_finished", true, true];
    };
};

if (isServer) then {
    if (missionNamespace getVariable ["MISSION_intro_sv", false]) exitWith {};
    missionNamespace setVariable ["MISSION_intro_sv", true];

    [] spawn {
        sleep 10;

        private _heliports = [];
        for "_i" from 0 to 200 do {
            private _hp = objNull;
            {
                private _var = missionNamespace getVariable [_x, objNull];
                if (!isNull _var) exitWith { _hp = _var; };
            } forEach [
                format ["Heliport_%1", _i],
                format ["Heliport_0%1", _i],
                format ["Heliport_00%1", _i]
            ];
            if (!isNull _hp) then { _heliports pushBack _hp; };
        };

        if (count _heliports == 0) then {
            _heliports = [vehicule_team];
            diag_log "[LL][intro] AVERTISSEMENT: Aucun Heliport_XXX trouvé — fallback vehicule_team.";
        };

        private _chosenHeliport = _heliports call BIS_fnc_selectRandom;
        private _destPos        = getPos _chosenHeliport;

        MISSION_intro_lz = _destPos;
        publicVariable "MISSION_intro_lz";

        vehicule_team setPos (_chosenHeliport getPos [15, getDir _chosenHeliport]);
        vehicule_team setDir (getDir _chosenHeliport);

        if (DEBUG_MODE) then {
            diag_log format ["[LL][intro] Héliport choisi: %1 pos: %2", _chosenHeliport, _destPos];
        };

        private _startDir = random 360;
        private _startPos = _chosenHeliport getPos [1300, _startDir];
        _startPos set [2, 200];

        private _heli = createVehicle ["CUP_I_UH60L_FFV_RACS", _startPos, [], 0, "FLY"];
        _heli setPos _startPos;
        _heli setDir (_startPos getDir _destPos);
        _heli flyInHeight 150;
        _heli allowDamage false;

        MISSION_intro_heli = _heli;
        publicVariable "MISSION_intro_heli";

        if (DEBUG_MODE) then { diag_log "[LL][intro] CUP_I_UH60L_FFV_RACS créé et synchronisé."; };

        createVehicleCrew _heli;
        private _crew = crew _heli;
        { _x allowDamage false; } forEach _crew;
        (group driver _heli) setBehaviour "CARELESS";
        (group driver _heli) setCombatMode "BLUE";

        private _players = playableUnits;
        if (count _players == 0 && hasInterface) then { _players = [player]; };

        private _allUnitsToBoard = [];
        private _processedGroups = [];

        {
            private _grp = group _x;
            if !(_grp in _processedGroups) then {
                _processedGroups pushBack _grp;
                {
                    if (alive _x && !(_x in _allUnitsToBoard)) then { _allUnitsToBoard pushBack _x; };
                } forEach (units _grp);
            };
        } forEach _players;

        {
            if (alive _x && !(_x in _allUnitsToBoard)) then { _allUnitsToBoard pushBack _x; };
        } forEach _players;

        {
            _x moveInCargo _heli;
            if (vehicle _x == _x) then { _x moveInAny _heli; };
            _x assignAsCargo _heli;
        } forEach _allUnitsToBoard;

        sleep 1;

        _heli doMove _destPos;
        _heli flyInHeight 150;
        _heli limitSpeed 200;

        sleep 21;

        [_heli, ["doorLB", 1]] remoteExec ["animateDoor", 0, true];
        [_heli, ["doorRB", 1]] remoteExec ["animateDoor", 0, true];
        _heli animateDoor ["doorLB", 1];
        _heli animateDoor ["doorRB", 1];
        sleep 5;   

        sleep 10;  

        _heli limitSpeed 110;
        sleep 14;

        waitUntil { (_heli distance2D _chosenHeliport) < 200 };
        _heli land "GET OUT";
        waitUntil { (getPosATL _heli select 2) < 2 };
        sleep 1;

        private _unitsToDisembark   = [];
        private _processedGroupsDis = [];

        {
            private _grp = group _x;
            if !(_grp in _processedGroupsDis) then {
                _processedGroupsDis pushBack _grp;
                {
                    if (alive _x && vehicle _x == _heli && !(_x in _unitsToDisembark)) then {
                        _unitsToDisembark pushBack _x;
                    };
                } forEach (units _grp);
            };
        } forEach _players;

        private _unitIndex = 0;
        {
            moveOut _x;
            unassignVehicle _x;
            private _dir         = getDir _heli;
            private _dist        = 6 + (_unitIndex mod 3);
            private _angleOffset = 60 + (_unitIndex * 14);
            private _pos         = _heli getPos [_dist, _dir + _angleOffset];
            _pos set [2, 0];
            _x setPos _pos;
            _x setDir _dir;
            _unitIndex = _unitIndex + 1;
        } forEach _unitsToDisembark;

        _heli setVehicleLock "LOCKED";
        _heli lock true;
        sleep 2;

        [_heli, ["doorLB", 0]] remoteExec ["animateDoor", 0, true];
        [_heli, ["doorRB", 0]] remoteExec ["animateDoor", 0, true];
        _heli animateDoor ["doorLB", 0];
        _heli animateDoor ["doorRB", 0];

        _heli land "NONE";
        _heli doMove (_destPos getPos [3000, _startDir]);
        _heli flyInHeight 200;
        _heli limitSpeed 300;

        sleep 70;
        { deleteVehicle _x } forEach _crew;
        deleteVehicle _heli;

        if (DEBUG_MODE) then { diag_log "[LL][intro] Hélicoptère supprimé."; };
    };
};
