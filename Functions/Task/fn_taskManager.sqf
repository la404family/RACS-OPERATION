params [["_mode", "init", [""]]];

if (!isServer) exitWith {};

if (_mode == "init") exitWith {
    missionNamespace setVariable ["LL_g_taskInProgress", false, true];
    missionNamespace setVariable ["LL_g_lastTask", "", true];
};

if (_mode == "REQUEST") exitWith {
    if (missionNamespace getVariable ["LL_g_taskInProgress", false]) exitWith {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then {
            diag_log "[LL] taskManager: Une tâche est déjà en cours.";
        };
    };

    private _availableTasks = [];
    _availableTasks pushBack "task00";
    _availableTasks pushBack "task01";
    _availableTasks pushBack "task02";
    _availableTasks pushBack "task03";
    _availableTasks pushBack "task04";
    _availableTasks pushBack "task05"; 
    _availableTasks pushBack "task06";
    
    private _lastTask = missionNamespace getVariable ["LL_g_lastTask", ""];

    private _validTasks = _availableTasks;
    if (count _availableTasks > 1 && _lastTask != "") then {
        _validTasks = _availableTasks select { _x != _lastTask };
    };

    if (count _validTasks > 0) then {
        private _selectedTask = selectRandom _validTasks;

        missionNamespace setVariable ["LL_g_lastTask", _selectedTask, true];
        missionNamespace setVariable ["LL_g_taskInProgress", true, true];

        private _fnc = missionNamespace getVariable ["LL_fnc_" + _selectedTask, {}];

        if (_fnc isNotEqualTo {}) then {
            if (missionNamespace getVariable ["DEBUG_MODE", true]) then {
                diag_log format ["[LL] taskManager: Lancement de la tâche '%1'.", _selectedTask];
            };
            ["init"] spawn _fnc;
        } else {
            if (missionNamespace getVariable ["DEBUG_MODE", true]) then {
                diag_log format ["[LL] taskManager: ERREUR - Fonction LL_fnc_%1 introuvable.", _selectedTask];
            };
            missionNamespace setVariable ["LL_g_taskInProgress", false, true];
        };
    } else {
        if (missionNamespace getVariable ["DEBUG_MODE", true]) then {
            diag_log "[LL] taskManager: Aucune tâche disponible (toutes sont commentées ou non définies).";
        };
    };
};
