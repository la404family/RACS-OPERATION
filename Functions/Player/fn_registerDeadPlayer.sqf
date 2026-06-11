if (!isServer) exitWith {};
params ["_netId"];
private _unit = objectFromNetId _netId;
if (isNull _unit) exitWith {};
if !(_unit in LL_g_deadPlayers) then {
    LL_g_deadPlayers pushBack _unit;
    publicVariable "LL_g_deadPlayers";
};
