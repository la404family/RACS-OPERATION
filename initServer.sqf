/*
    File: initServer.sqf
    Description: Exécuté uniquement sur le serveur (ou l'hôte local) au lancement de la mission.
    Note : Le lancement de l'Ezan et de la météo a été déplacé dans init.sqf (avec isServer) 
    pour garantir une exécution parfaite en mode SinglePlayer (SP) depuis l'éditeur.
*/

[] spawn LL_fnc_randomWeather;
[] spawn LL_fnc_initSkills;
[] spawn LL_fnc_initCivilians;
[] spawn LL_fnc_heliManager;
