/*
    File: fn_setupUVO.sqf
    Description: Configure les variables du mod Unit Voice-Overs (UVO) pour forcer
                 la langue (Anglais pour RACS, Arabe/Perse pour les locaux).
    Locality: N'importe où (Effet global via setVariable)
*/

params [["_unit", objNull, [objNull]]];

if (isNull _unit || !alive _unit) exitWith {};

private _uvoLang = "";

// Les unités Indépendantes (RACS/Joueurs) parlent Anglais
if (side _unit == independent) then {
    _uvoLang = selectRandom ["English", "American English"];
} else {
    // Les Civils, OPFOR, et BLUFOR (ennemis/locaux) parlent Perse ou Arabe
    _uvoLang = selectRandom ["Arabic", "Persian"];
};

// Variables principales (les plus compatibles avec les différentes versions d'UVO)
_unit setVariable ["UVO_Voice", _uvoLang, true];
_unit setVariable ["UVO_Language", _uvoLang, true];

// Variables de désactivation de l'auto-détection (désactive le script natif du mod pour éviter les conflits)
{
    _unit setVariable [_x, true, true];
} forEach [
    "uvo_disable_auto",
    "UVO_disableAuto",
    "UVO_autoAssign",
    "uvo_autoDetect"
];
