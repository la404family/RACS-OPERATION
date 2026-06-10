if (!hasInterface) exitWith {};

// Création de la catégorie principale "Manuel Opérationnel" si elle n'existe pas
if (!(player diarySubjectExists "Manuel")) then {
    player createDiarySubject ["Manuel", localize "STR_LL_Briefing_Manual_Tab"];
};

// Ajout des pages dans l'ordre inverse pour qu'elles s'affichent correctement de 1.1 à 3.1
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_3_1_Title", localize "STR_LL_Briefing_3_1_Text"]];
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_2_3_Title", localize "STR_LL_Briefing_2_3_Text"]];
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_2_2_Title", localize "STR_LL_Briefing_2_2_Text"]];
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_2_1_Title", localize "STR_LL_Briefing_2_1_Text"]];
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_1_4_Title", localize "STR_LL_Briefing_1_4_Text"]];
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_1_3_Title", localize "STR_LL_Briefing_1_3_Text"]];
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_1_2_Title", localize "STR_LL_Briefing_1_2_Text"]];
player createDiaryRecord ["Manuel", [localize "STR_LL_Briefing_1_1_Title", localize "STR_LL_Briefing_1_1_Text"]];
