if (!isServer) exitWith {};
params ["_netId"];
private _unit = objectFromNetId _netId;
LL_g_deadPlayers = LL_g_deadPlayers select { !isNull _x && _x != _unit };
publicVariable "LL_g_deadPlayers";
