if (!hasInterface) exitWith {};

if (!(player diarySubjectExists "Manuel")) then {
    player createDiarySubject ["Manuel", localize "STR_LL_Briefing_Manual_Tab"];
};

player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_3_1_Title", localize "STR_LL_Briefing_3_1_Text"]];
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_2_3_Title", localize "STR_LL_Briefing_2_3_Text"]];
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_2_2_Title", localize "STR_LL_Briefing_2_2_Text"]];
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_2_1_Title", localize "STR_LL_Briefing_2_1_Text"]];
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_1_3_Title", localize "STR_LL_Briefing_1_3_Text"]];
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_1_1_Title", localize "STR_LL_Briefing_1_1_Text"]];


