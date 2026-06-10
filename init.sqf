/*
    File: init.sqf
    Description: Exécuté au lancement de la mission, sur le serveur et sur tous les clients (y compris les JIP).
    Note: Privilégiez initServer.sqf et initPlayerLocal.sqf pour la séparation logique.
*/

// Initialisations globales (si nécessaire)

if (isServer) then {
    [] call LL_fnc_randomWeather;
    [] spawn LL_fnc_playEzan;
    [] spawn LL_fnc_doorSecurity;
    [] spawn LL_fnc_manageInsurgents;
    
    [] spawn LL_fnc_initIdentity;
    [] spawn LL_fnc_initLoadout;

    [] call LL_fnc_initCivilians;
    [] spawn LL_fnc_spawnPresence;
    
    [] spawn LL_fnc_assignLeader;
};
