if (!isServer) exitWith {};

if (missionNamespace getVariable ["DEBUG_MODE", true]) then {
    diag_log "[LL] task00: Initialisation de la tâche modèle.";
};

// [A FAIRE] Définir votre logique de tâche ici
// Exemple : Création d'une tâche via BIS_fnc_taskCreate
/*
[
    independent,
    ["task_00_recon"],
    [
        localize "STR_LL_Task_00_Desc",
        localize "STR_LL_Task_00_Title",
        localize "STR_LL_Task_00_Marker"
    ],
    getMarkerPos "marker_task00",
    "AUTOASSIGNED",
    5,
    true,
    "recon"
] call BIS_fnc_taskCreate;
*/
