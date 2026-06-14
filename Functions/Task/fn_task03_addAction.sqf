if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addAction = {
        params ["_unit"];
        if (_unit getVariable ["LL_Task03_Action_Added", false]) exitWith {};
        _unit setVariable ["LL_Task03_Action_Added", true];

        if (isNil "LL_fnc_task03_cond") then {
            LL_fnc_task03_cond = {
                params ["_target", "_caller"];
                private _rawRadios = missionNamespace getVariable ["LL_Task03_Radios", []];
                if (count _rawRadios == 0) exitWith { false };
                private _radios = [];
                {
                    private _r = if (_x isEqualType "") then { objectFromNetId _x } else { _x };
                    if (!isNull _r) then { _radios pushBack _r; };
                } forEach _rawRadios;

                private _found = false;
                {
                    if (alive _x && _target distance _x < 4 && (_x getVariable ["LL_Task_Status", "WAIT"] == "WAIT")) exitWith {
                        _found = true;
                    };
                } forEach _radios;
                _found
            };
        };

        _unit addAction [
            format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_03_Action"],
            {
                params ["_target", "_caller", "_actionId"];
                private _rawRadios = missionNamespace getVariable ["LL_Task03_Radios", []];
                private _radios = [];
                {
                    private _r = if (_x isEqualType "") then { objectFromNetId _x } else { _x };
                    if (!isNull _r) then { _radios pushBack _r; };
                } forEach _rawRadios;
                _radios = _radios select {
                    alive _x && _caller distance _x < 4 && (_x getVariable ["LL_Task_Status", "WAIT"] == "WAIT")
                };
                if (count _radios == 0) exitWith {};
                private _radio = _radios select 0;

                if (_radio getVariable ["LL_Task03_Triggered", false]) exitWith {};
                _radio setVariable ["LL_Task03_Triggered", true, true];

                ["plant", [_radio, _caller]] remoteExec ["LL_fnc_task03", 2];
            },
            nil,
            6,
            true,
            true,
            "",
            "alive _target && { [_target, _this] call LL_fnc_task03_cond }"
        ];
    };

    private _lastPlayer = objNull;
    while { true } do {
        waitUntil { sleep 1; player != _lastPlayer && !isNull player };
        _lastPlayer = player;
        [_lastPlayer] call _fnc_addAction;
    };
};
