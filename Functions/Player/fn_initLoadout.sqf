if (!isServer) exitWith {};

private _vests = [
    "CUP_V_JPC_medical_coy","CUP_V_JPC_tl_coy","CUP_V_JPC_weapons_coy",
    "CUP_V_JPC_communicationsbelt_coy","CUP_V_JPC_Fastbelt_coy","CUP_V_JPC_lightbelt_coy",
    "CUP_V_JPC_medicalbelt_coy","CUP_V_JPC_tlbelt_coy","CUP_V_JPC_weaponsbelt_coy"
];
private _helmets = [
    "CUP_H_OpsCore_Tan_SF","CUP_H_OpsCore_Tan","CUP_H_OpsCore_Tan_NohS",
    "CUP_H_OpsCore_Grey_SF","CUP_H_OpsCore_Grey","CUP_H_OpsCore_Grey_NohS"
];
private _backpacks = ["CUP_B_AssaultPack_Coyote","B_AssaultPack_cbr","B_Kitbag_cbr"];
private _uniforms = [
    "CUP_U_B_USMC_MCCUU_des_gloves","CUP_U_B_USMC_MCCUU_des_roll_2",
    "CUP_U_B_USMC_MCCUU_des_roll_2_gloves","CUP_U_B_USMC_MCCUU_des_roll_pads",
    "CUP_U_B_USMC_MCCUU_des_roll_2_pads_gloves","CUP_U_B_USMC_MCCUU_des_pads",
    "CUP_U_B_USMC_MCCUU_des_pads_gloves","CUP_U_B_USMC_MCCUU_des_roll",
    "CUP_U_B_USMC_MCCUU_des_roll_gloves","CUP_U_B_USMC_MCCUU_des_roll_pads",
    "CUP_U_B_USMC_MCCUU_des_roll_pads_gloves","CUP_U_B_USMC_MCCUU_des"
];
private _goggles = [
    "CUP_G_Tan_Scarf_Shades_GPSCombo_Beard","CUP_G_Tan_Scarf_Shades_GPS_Beard",
    "CUP_G_Tan_Scarf_GPS","CUP_G_TK_RoundGlasses_blk","CUP_G_Oakleys_Drk",
    "CUP_G_Scarf_Face_Tan","G_Aviator","CUP_G_ESS_KHK_Scarf_Tan_GPS_Beard",
    "CUP_G_ESS_KHK_Facewrap_Tan","G_Bandana_khk"
];

private _units = [];
for "_i" from 0 to 99 do {
    private _s = if (_i < 10) then { format ["0%1", _i] } else { str _i };
    private _u = missionNamespace getVariable [format ["player_%1", _s], objNull];
    if (!isNull _u && alive _u) then { _units pushBack _u; };
};

if (count _units == 0) exitWith {};

private _endTime = time + 120;
while { time < _endTime } do {
    private _todo = _units select { alive _x && !(_x getVariable ["LL_LoadoutSet", false]) };
    if (count _todo == 0) exitWith {};

    {
        private _unit = _x;
        private _data = [
            selectRandom _uniforms,
            selectRandom _vests,
            selectRandom _backpacks,
            selectRandom _helmets,
            selectRandom _goggles
        ];

        if (local _unit) then {
            [_unit, _data] call LL_fnc_applyLoadout;
        } else {
            [_unit, _data] remoteExec ["LL_fnc_applyLoadout", _unit];
        };
    } forEach _todo;

    sleep 3;
};
