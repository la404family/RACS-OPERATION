params [["_unit", objNull, [objNull]], ["_nameData", [], [[]]], ["_face", "", [""]], ["_speaker", "", [""]], ["_pitch", 1.0, [0.0]], ["_goggles", "", [""]]];
if (isNull _unit) exitWith { false };
if (count _nameData > 0) then {
    if (count _nameData >= 3) then {
        _unit setName [_nameData select 0, _nameData select 1, _nameData select 2];
    } else {
        _unit setName (_nameData select 0);
    };
};
if (_face != "") then { _unit setFace _face };
if (_speaker != "") then { _unit setSpeaker _speaker };
if (_pitch > 0) then { _unit setPitch _pitch };
if (_goggles != "") then {
    removeGoggles _unit;
    _unit addGoggles _goggles;
};
true
