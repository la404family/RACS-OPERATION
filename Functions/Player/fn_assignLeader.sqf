/*
    File: fn_assignLeader.sqf
    Description: Surveille le groupe des joueurs et s'assure qu'un joueur humain 
                 est toujours le leader. Ramène également les joueurs dispersés dans le même groupe.
    Locality: Serveur uniquement
*/

if (!isServer) exitWith {};

[] spawn {
    // Attendre le début effectif de la mission
    waitUntil { time > 0 };
    sleep 2;

    // Boucle de surveillance continue
    while {true} do {
        sleep 5;
        
        private _activePlayers = allPlayers - entities "HeadlessClient_F";
        private _livingPlayers = _activePlayers select { alive _x };
        
        if (_livingPlayers isNotEqualTo []) then {
            // On identifie le groupe principal (via player_00 par défaut)
            private _mainGrp = group (missionNamespace getVariable ["player_00", objNull]);
            
            // Fallback si player_00 n'existe plus ou est introuvable
            if (isNull _mainGrp) then {
                _mainGrp = group (_livingPlayers select 0);
            };

            if (!isNull _mainGrp) then {
                // 1. S'assurer que tous les joueurs vivants sont dans le groupe principal
                {
                    if (group _x != _mainGrp) then {
                        [_x] joinSilent _mainGrp;
                    };
                } forEach _livingPlayers;

                // 2. Si le leader du groupe principal n'est pas un joueur (ex: une IA), on le remplace
                if (!isPlayer (leader _mainGrp)) then {
                    private _newLeader = _livingPlayers select 0;
                    _mainGrp selectLeader _newLeader;
                    
                    // Notification d'immersion (optionnelle)
                    ["QG : Changement de commandement sur le terrain. Un officier humain a repris le lead."] remoteExec ["systemChat", _livingPlayers];
                };
            };
        };
    };
};
