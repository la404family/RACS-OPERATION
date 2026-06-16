params [
    ["_stringKey", "", [""]],
    ["_formatArgs", [], [[]]],
    ["_duration", 6, [0]],
    ["_playAudio", true, [true]]
];

if (_stringKey isEqualTo "") exitWith {};

if (_playAudio) then {
    playSound _stringKey;
};

private _localizedText = localize _stringKey;
if (_localizedText isEqualTo "") then {
    if (_stringKey isEqualTo "STR_Drone_Jammed") then {
        _localizedText = "Brouillage radio détecté. Impossible de contacter le drone.";
    } else {
        _localizedText = _stringKey;
    };
};
if (count _formatArgs > 0) then {
    _localizedText = format ([_localizedText] + _formatArgs);
};

private _structuredText = format ["<t size='1.2' shadow='2' align='center'>%1</t>", _localizedText];

[_structuredText, _duration] spawn {
    params ["_text", "_time"];

    cutText [_text, "PLAIN DOWN", 0.5, true, true];

    sleep _time;

    cutText ["", "PLAIN DOWN", 0.5];
};
