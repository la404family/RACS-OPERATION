if (!hasInterface) exitWith {};

_this spawn {
    params [["_corpse", objNull, [objNull]], ["_doc", objNull, [objNull]]];

    private _timeout = time + 15;
    waitUntil { (!isNull _corpse && !isNull _doc) || time > _timeout };

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
        "alive _target == false && _this distance _target < 4"
    ];
};
