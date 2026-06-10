if (!hasInterface) exitWith {};

if (!(player diarySubjectExists "Context")) then {
    player createDiarySubject ["Context", localize "STR_LL_Context_Tab"];
};

player createDiaryRecord ["Context", [localize "STR_LL_Context_3_Title", localize "STR_LL_Context_3_Text"]];
player createDiaryRecord ["Context", [localize "STR_LL_Context_2_Title", localize "STR_LL_Context_2_Text"]];
player createDiaryRecord ["Context", [localize "STR_LL_Context_1_Title", localize "STR_LL_Context_1_Text"]];
