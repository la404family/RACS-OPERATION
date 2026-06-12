params ["_player", "_didJIP"];
[] spawn LL_fnc_intro;
[] spawn LL_fnc_initLocal;
[] spawn LL_fnc_addDroneAction;
[] spawn LL_fnc_addHelicopterActions;
[] spawn LL_fnc_addRallyAction;
[] spawn LL_fnc_addHealAction;
// [] spawn LL_fnc_addSearchAction;
[] spawn LL_fnc_addTaskAction;
[] spawn LL_fnc_addRoeActions;
[] spawn LL_fnc_initBriefing;
[] spawn LL_fnc_initContext;

player addEventHandler ["Killed", {
    [netId player] remoteExec ["LL_fnc_registerDeadPlayer", 2];
}];

player addEventHandler ["Respawn", {
    [netId player] remoteExec ["LL_fnc_unregisterDeadPlayer", 2];
}];
