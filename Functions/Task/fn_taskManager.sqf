if (!isServer) exitWith {};

private _availableTasks = [];

// Pour tester, décommentez les tâches que vous voulez rendre disponibles
// _availableTasks pushBack "task00";
// _availableTasks pushBack "task01";

// S'assure de ne sélectionner qu'une seule tâche au hasard parmi celles disponibles
if (count _availableTasks > 0) then {
    private _selectedTask = selectRandom _availableTasks;
    private _fnc = missionNamespace getVariable ["LL_fnc_" + _selectedTask, {}];
    
    if (_fnc isNotEqualTo {}) then {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then {
            diag_log format ["[LL] taskManager: Lancement de la tâche '%1'.", _selectedTask];
        };
        [] spawn _fnc;
    } else {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then {
            diag_log format ["[LL] taskManager: ERREUR - Fonction LL_fnc_%1 introuvable.", _selectedTask];
        };
    };
} else {
    if (missionNamespace getVariable ["DEBUG_MODE", true]) then {
        diag_log "[LL] taskManager: Aucune tâche disponible (toutes sont commentées ou non définies).";
    };
};
