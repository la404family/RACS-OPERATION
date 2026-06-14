if (!hasInterface) exitWith {};

_this spawn {
    params [
        ["_corpseParam", objNull, [objNull]], ["_corpseNetId", "", [""]], ["_corpseVar", "", [""]],
        ["_docParam", objNull, [objNull]], ["_docNetId", "", [""]], ["_docVar", "", [""]]
    ];

    private _corpse = _corpseParam;
    if (isNull _corpse) then {
        private _timeout = time + 30;
        waitUntil {
            sleep 0.5;
            if (_corpseNetId != "") then { _corpse = objectFromNetId _corpseNetId; };
            if (isNull _corpse && _corpseVar != "") then { _corpse = missionNamespace getVariable [_corpseVar, objNull]; };
            !isNull _corpse || time > _timeout
        };
    };

    private _doc = _docParam;
    if (isNull _doc) then {
        private _timeout = time + 30;
        waitUntil {
            sleep 0.5;
            if (_docNetId != "") then { _doc = objectFromNetId _docNetId; };
            if (isNull _doc && _docVar != "") then { _doc = missionNamespace getVariable [_docVar, objNull]; };
            !isNull _doc || time > _timeout
        };
    };

    if (isNull _corpse || isNull _doc) exitWith {};

    _doc addAction [
        format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_01_Action"],
        {
            params ["_target", "_caller", "_actionId", "_arguments"];
            _arguments params ["_corpse"];

            _target removeAction _actionId;

            if (_caller canAdd "ItemMap") then {
                _caller addItem "ItemMap";
            };

            ["collect", [_corpse, _target]] remoteExec ["LL_fnc_task01", 2];
        },
        [_corpse],
        10,
        true,
        true,
        "",
        "_this distance _target < 4",
        4
    ];
};
