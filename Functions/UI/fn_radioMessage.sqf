/*
    Author: Antigravity
    Description:
    Joue un son radio (TTS) et affiche le sous-titre localisé correspondant dans la zone basse de l'écran.
    
    Arguments:
    0: STRING - La clé de localisation et nom de la classe CfgSounds (ex: "STR_Drone_Approach")
    1: ARRAY - (Optionnel) Les arguments pour formater le texte si nécessaire (ex: [10] pour "%1 minutes")
    2: NUMBER - (Optionnel) Durée d'affichage du sous-titre en secondes (Défaut: 6)
    
    Exemple d'utilisation (doit s'exécuter localement là où le son/texte doit être perçu):
    ["STR_Drone_Approach", [10]] call LL_fnc_radioMessage;
*/

params [
    ["_stringKey", "", [""]],
    ["_formatArgs", [], [[]]],
    ["_duration", 6, [0]]
];

if (_stringKey isEqualTo "") exitWith {};

// 1. Jouer le son
playSound _stringKey;

// 2. Préparer le texte localisé
private _localizedText = localize _stringKey;
if (count _formatArgs > 0) then {
    _localizedText = format ([_localizedText] + _formatArgs);
};

// 3. Afficher le sous-titre dans la zone rouge (PLAIN DOWN)
// L'absence de paramètre 'font' permet à Arma d'utiliser la police par défaut du système,
// garantissant la compatibilité avec toutes les langues (Chinois, Coréen, etc.)
private _structuredText = format ["<t size='1.2' shadow='2' align='center'>%1</t>", _localizedText];

// On utilise un spawn pour gérer l'effacement du texte après la durée définie
[_structuredText, _duration] spawn {
    params ["_text", "_time"];
    
    // Affichage avec un fondu de 0.5s
    cutText [_text, "PLAIN DOWN", 0.5, true, true];
    
    sleep _time;
    
    // Effacement avec un fondu de 0.5s
    cutText ["", "PLAIN DOWN", 0.5];
};
