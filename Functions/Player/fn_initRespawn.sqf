if (!isServer) exitWith {};
if (isNil "LL_g_deadPlayers") then {
    LL_g_deadPlayers = [];
    publicVariable "LL_g_deadPlayers";
};
