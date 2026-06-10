if (!isServer) exitWith {};

[] spawn {
    
    waitUntil { time > 0 };
    sleep 2;

    while {true} do {
        sleep 5;
        
        private _activePlayers = allPlayers - entities "HeadlessClient_F";
        private _livingPlayers = _activePlayers select { alive _x };
        
        if (_livingPlayers isNotEqualTo []) then {
            
            private _mainGrp = group (missionNamespace getVariable ["player_00", objNull]);
            
            if (isNull _mainGrp) then {
                _mainGrp = group (_livingPlayers select 0);
            };

            if (!isNull _mainGrp) then {
                
                {
                    if (group _x != _mainGrp) then {
                        [_x] joinSilent _mainGrp;
                    };
                } forEach _livingPlayers;

                if (!isPlayer (leader _mainGrp)) then {
                    private _newLeader = _livingPlayers select 0;
                    _mainGrp selectLeader _newLeader;
                    
                    ["STR_LL_AssignLeader_Changed"] remoteExec ["LL_fnc_radioMessage", _livingPlayers];
                };
            };
        };
    };
};
