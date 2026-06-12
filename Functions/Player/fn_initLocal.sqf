if (!hasInterface) exitWith {};

player createDiaryRecord ["diary", [localize "STR_LL_Diary_Lore_Title", localize "STR_LL_Diary_Lore_Text"]];
player createDiaryRecord ["diary", [localize "STR_LL_Diary_Factions_Title", localize "STR_LL_Diary_Factions_Text"]];
player createDiaryRecord ["diary", [localize "STR_LL_Diary_Context_Title", localize "STR_LL_Diary_Context_Text"]];
player createDiaryRecord ["diary", [localize "STR_LL_Briefing_Title", localize "STR_LL_Briefing_Text"]];

[] spawn {
    private _timeout = 0;
    waitUntil {
        sleep 0.5;
        _timeout = _timeout + 0.5;
        (!isNull player && {!isNil { player getVariable "LL_s_identity" }}) || { _timeout >= 30 }
    };

    private _playerUnit = player;
    if (!isNull _playerUnit) then {
        private _identity = _playerUnit getVariable ["LL_s_identity", []];
        if (count _identity >= 5) then {
            _identity params ["_nameData", "_faceType", "_face", "_speaker", "_pitch", ["_beard", "", [""]]];
            [_playerUnit, _nameData, _face, _speaker, _pitch, _beard] call LL_fnc_applyIdentity;
            showHUD false;
            sleep 0.5;
            showHUD true;
        };
    };
};
