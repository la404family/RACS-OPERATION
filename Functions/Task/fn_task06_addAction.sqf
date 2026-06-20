if (!hasInterface) exitWith {};

_this spawn {
    params [["_hvtParam", objNull, [objNull]], ["_netId", "", [""]]];

    private _hvt = _hvtParam;
    if (isNull _hvt) then {
        private _timeout = time + 30;
        waitUntil {
            sleep 0.5;
            if (_netId != "") then { _hvt = objectFromNetId _netId; };
            if (isNull _hvt) then { _hvt = missionNamespace getVariable ["LL_Task06_HVT", objNull]; };
            !isNull _hvt || time > _timeout
        };
    };

    if (isNull _hvt) exitWith {
        diag_log "[CLIENT] ERREUR : Le HVT reçu par addAction est null (problème de réplication).";
    };

    private _status = _hvt getVariable ["LL_Task_Status", ""];

    private _titleEscort = localize "STR_LL_Task_06_EscortAction";
    if (_titleEscort == "" || _titleEscort == "STR_LL_Task_06_EscortAction") then { _titleEscort = "Escort HVT"; };

    private _titleRelease = localize "STR_LL_Task_06_ReleaseAction";
    if (_titleRelease == "" || _titleRelease == "STR_LL_Task_06_ReleaseAction") then { _titleRelease = "Release HVT"; };

    _hvt addAction [
        format ["<t color='#FFFF00'>%1</t>", _titleEscort],
        {
            params ["_target", "_caller", "_actionId"];
            ["escort", [_target, _caller]] remoteExec ["LL_fnc_task06", 2];
        },
        nil, 6.0, true, true, "",
        "alive _target && _this distance _target < 4 && (_target getVariable ['LL_Task_Status', '']) == 'READY_TO_CAPTURE'"
    ];

    _hvt addAction [
        format ["<t color='#FF8800'>%1</t>", _titleRelease],
        {
            params ["_target", "_caller", "_actionId"];
            ["release", [_target, _caller]] remoteExec ["LL_fnc_task06", 2];
        },
        nil, 6.0, true, true, "",
        "alive _target && (_target getVariable ['LL_Task_Status', '']) == 'ESCORTED' && (_target getVariable ['LL_Task06_EscortParent', objNull]) == _this"
    ];

};
