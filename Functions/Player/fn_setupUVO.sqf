params [["_unit", objNull, [objNull]]];

if (isNull _unit || !alive _unit) exitWith {};

private _uvoLang = "";

if (side _unit == independent) then {
    _uvoLang = selectRandom ["English", "American English"];
} else {

    _uvoLang = selectRandom ["Arabic", "Persian"];
};

_unit setVariable ["UVO_Voice", _uvoLang, true];
_unit setVariable ["UVO_Language", _uvoLang, true];

{
    _unit setVariable [_x, true, true];
} forEach [
    "uvo_disable_auto",
    "UVO_disableAuto",
    "UVO_autoAssign",
    "uvo_autoDetect"
];
