[] spawn LL_fnc_initSkills;
[] spawn LL_fnc_heliManager;
[] spawn LL_fnc_intro;
[] call LL_fnc_initRespawn;
[] spawn LL_fnc_spawnStartArsenal;

[] spawn {
    waitUntil { sleep 1; missionNamespace getVariable ["MISSION_intro_finished", false] };
    [] spawn LL_fnc_taskManager;
};
