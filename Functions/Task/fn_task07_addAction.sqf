if (!hasInterface) exitWith {};

_this spawn {
    params [
        ["_unitParam", objNull, [objNull]],
        ["_netId", "", [""]],
        ["_varName", "", [""]],
        ["_mode", "talk", [""]]
    ];

    private _unit = _unitParam;
    if (isNull _unit) then {
        private _timeout = time + 30;
        waitUntil {
            sleep 0.5;
            if (_netId != "") then { _unit = objectFromNetId _netId; };
            if (isNull _unit && _varName != "") then { _unit = missionNamespace getVariable [_varName, objNull]; };
            !isNull _unit || time > _timeout
        };
    };

    if (isNull _unit) exitWith {};

    private _actionLabel = if (_mode == "talk") then {
        localize "STR_LL_Task_07_Action"
    } else {
        localize "STR_LL_Task_07_ActionThanks"
    };

    private _triggerVar = switch (_mode) do {
        case "talk": { "LL_Task07_Talk_Triggered" };
        case "thanks": { "LL_Task07_Thanks_Triggered" };
        case "defeat": { "LL_Task07_Defeat_Triggered" };
        default { "LL_Task07_Thanks_Triggered" };
    };

    _unit addAction [
        format ["<t color='#FFFF00'>%1</t>", _actionLabel],
        {
            params ["_target", "_caller", "_actionId", "_customParams"];
            _customParams params ["_mode", "_triggerVar"];

            if (missionNamespace getVariable [_triggerVar, false]) exitWith {};
            missionNamespace setVariable [_triggerVar, true, true];

            _target removeAction _actionId;
            _caller playActionNow "PutDown";

            switch (_mode) do {
                case "talk": { ["talk", [_target, _caller]] remoteExec ["LL_fnc_task07", 2]; };
                case "thanks": { ["complete", [_target, _caller]] remoteExec ["LL_fnc_task07", 2]; };
                case "defeat": { ["complete_defeat", [_target, _caller]] remoteExec ["LL_fnc_task07", 2]; };
            };
        },
        [_mode, _triggerVar],
        6.0,
        true,
        true,
        "",
        "alive _target && _this distance _target < 4",
        4
    ];
};
