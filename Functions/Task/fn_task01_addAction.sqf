/*
    LL_fnc_task01_addAction
    Client uniquement.
*/
params ["_corpse", "_doc"];

if (!hasInterface) exitWith {};

_corpse addAction [
    format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_01_Action"],
    {
        params ["_target", "_caller", "_actionId", "_arguments"];
        _arguments params ["_doc"];
        
        _target removeAction _actionId;
        
        // Simuler la récupération de document
        if (_caller canAdd "ItemMap") then {
            _caller addItem "ItemMap";
        };
        
        // Appeler la suite sur le serveur
        ["collect", [_target, _doc]] remoteExec ["LL_fnc_task01", 2];
    },
    [_doc],
    10,
    true,
    true,
    "",
    "alive _target == false && _this distance _target < 4"
];
