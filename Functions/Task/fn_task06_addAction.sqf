if (!hasInterface) exitWith {};

_this spawn {
    params [["_hvt", objNull, [objNull]]];

    private _timeout = time + 10;
    waitUntil { !isNull _hvt || time > _timeout };

    if (isNull _hvt) exitWith {
        systemChat "[CLIENT] ERREUR : Le HVT reçu par addAction est null (problème de réplication).";
    };

    private _status = _hvt getVariable ["LL_Task_Status", ""];
    systemChat format ["[CLIENT] HVT validé : %1 (Statut : %2). Ajout des actions...", _hvt, _status];

    private _titleEscort = localize "STR_LL_Task_06_EscortAction";
    if (_titleEscort == "" || _titleEscort == "STR_LL_Task_06_EscortAction") then { _titleEscort = "Escorter le HVT"; };

    private _titleRelease = localize "STR_LL_Task_06_ReleaseAction";
    if (_titleRelease == "" || _titleRelease == "STR_LL_Task_06_ReleaseAction") then { _titleRelease = "Relâcher le HVT"; };

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
        "alive _target && (_target getVariable ['LL_Task_Status', '']) == 'ESCORTED' && attachedTo _target == _this"
    ];

    systemChat "[CLIENT] Actions d'escorte et de libération configurées sur le HVT.";
};
