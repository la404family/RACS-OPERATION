if (!hasInterface) exitWith {};

_this spawn {
    params [["_corpseParam", objNull, [objNull, ""]], ["_docParam", objNull, [objNull, ""]]];

    private _corpse = objNull;
    if (_corpseParam isEqualType "") then {
        waitUntil {
            sleep 0.5;
            _corpse = objectFromNetId _corpseParam;
            if (isNull _corpse) then {
                _corpse = missionNamespace getVariable [_corpseParam, objNull];
            };
            !isNull _corpse
        };
    } else {
        _corpse = _corpseParam;
    };

    private _doc = objNull;
    if (_docParam isEqualType "") then {
        waitUntil {
            sleep 0.5;
            _doc = objectFromNetId _docParam;
            if (isNull _doc) then {
                _doc = missionNamespace getVariable [_docParam, objNull];
            };
            !isNull _doc
        };
    } else {
        _doc = _docParam;
    };

    if (isNull _corpse || isNull _doc) exitWith {};

    _corpse addAction [
        format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_01_Action"],
        {
            params ["_target", "_caller", "_actionId", "_arguments"];
            _arguments params ["_doc"];

            _target removeAction _actionId;

            if (_caller canAdd "ItemMap") then {
                _caller addItem "ItemMap";
            };

            ["collect", [_target, _doc]] remoteExec ["LL_fnc_task01", 2];
        },
        [_doc],
        10,
        true,
        true,
        "",
        "alive _target == false && _this distance _target < 4",
        4
    ];
};
