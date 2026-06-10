/*
    File: initPlayerLocal.sqf
    Description: Exécuté uniquement localement lorsqu'un joueur rejoint la partie (JIP inclus).
    Paramètres :
        _this select 0: Object - l'unité du joueur.
        _this select 1: Boolean - true si le joueur a rejoint en cours de partie (JIP).
*/

params ["_player", "_didJIP"];
[] spawn LL_fnc_initLocal;
[] spawn LL_fnc_addDroneAction;
[] spawn LL_fnc_addHelicopterActions;
[] spawn LL_fnc_addRallyAction;
[] spawn LL_fnc_addHealAction;
[] spawn LL_fnc_addSearchAction;
[] spawn LL_fnc_addRoeActions;
