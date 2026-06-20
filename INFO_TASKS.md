# TASK_RULES.md — Règles de codage des missions

Ce document est la référence obligatoire pour tout développement de tâche dans cette mission.
Il s'adresse à un agent IA ou développeur qui doit coder une nouvelle tâche, une interaction PNJ ou un scénario.

---

## 1. Architecture des fichiers

```
tasks/
  fn_taskXX.sqf            ← Logique serveur de la tâche (spawn, scénarios, états)
  fn_taskXX_addAction.sqf  ← Ajout des addActions côté client (hasInterface)
  taskXX_tasks.xml         ← Titres, descriptions et marqueurs de tâche (STR_LL_Task_XX_*)
  taskXX_dialogues.xml     ← Dialogues PNJ et narrateur (STR_LL_Task_XX_S*)
  taskXX_briefing.xml      ← Briefing de la tâche (STR_LL_Diary_*)
```

- Chaque tâche a son propre ensemble de fichiers XML dans `tasks/`.
- Toute modification des textes se fait dans `tasks/*.xml`, jamais dans `stringtable.xml` directement.
- Après modification XML, régénérer avec : `python compile_stringtable.py`
- Toujours enregistrer les fichiers XML en **UTF-8 sans BOM**.

---

## 2. Localité d'exécution

| Responsabilité | Machine |
|---|---|
| Spawn d'unités, logique de tâche, `BIS_fnc_taskCreate`, `BIS_fnc_taskSetState` | **Serveur** (`isServer`) |
| `addAction` sur PNJ ou objets | **Client** (`hasInterface`) via `remoteExec` |
| `showSubtitle`, `systemChat`, marqueurs de carte | **Tous** (`remoteExec [..., 0]`) |
| Lecture de l'inventaire, contrôle de la caméra | **Client local** |

Toujours utiliser `if (!isServer) exitWith {};` en tête des scripts serveur.  
Toujours utiliser `if (!hasInterface) exitWith {};` en tête des scripts client.

---

## 3. Règles de spawn des PNJ

### Z + 0.2 obligatoire
Tout PNJ ou objet spawné dans ou près d'un bâtiment **doit être positionné à Z + 0.2** pour éviter les collisions avec les géométries intérieures.

```sqf
private _pos = getPosASL _logique;
_pos set [2, (_pos select 2) + 0.2];
_unit setPosASL _pos;
```

### Protection anti-collision au spawn
Après chaque `createUnit`, désactiver temporairement les dommages pendant **3 secondes** pour éviter les morts instantanées lors du chargement de la géométrie.

```sqf
_unit allowDamage false;
[_unit] spawn { sleep 3; (_this select 0) allowDamage true; };
```

### Distance minimale de sécurité (950m)
Toute tâche générée aléatoirement doit respecter des règles strictes de distance pour éviter le spawn sous les yeux des joueurs :
- **Minimum 950m** entre le lieu de la tâche et n'importe quel joueur vivant sur le serveur.
- S'il y a plusieurs lieux pour une même tâche, ils doivent être espacés d'au moins **250m** entre eux.

### Ordre de spawn : secondaires avant principal
Quand une scène comporte une unité principale (chef de milice, otage, cible, bombe...) et des unités secondaires (gardes, sentinelles...) :

1. Faire spawner les **unités secondaires** en premier.
2. Les faire **patrouiller** aléatoirement dans la zone.
3. Attendre un délai de **1.5 seconde** entre chaque spawn secondaire.
4. Faire spawner l'**unité principale** en dernier.

```sqf
for "_i" from 0 to (_numGuards - 1) do {
    sleep 1.5;
    // ... spawn du garde ...
};
// Puis spawn du chef
```

---

## 4. Comportement des PNJ en attente d'interaction

### Animation d'attente loopée
Un PNJ en attente d'interaction doit jouer une animation civile en boucle via un `EventHandler`.

```sqf
_unit disableAI "MOVE";
_unit disableAI "ANIM";
_unit setUnitPos "UP";
_unit switchMove "Acts_CivilTalking_1";

_unit addEventHandler ["AnimDone", {
    params ["_unit"];
    if (alive _unit && (_unit getVariable ["LL_Task_Status", "WAIT"]) == "WAIT") then {
        _unit switchMove "Acts_CivilTalking_1";
    };
}];
```

### Rotation vers le joueur le plus proche
Tout PNJ principal qui attend une interaction doit **se tourner vers le joueur le plus proche** toutes les 2 secondes, tant qu'il est en phase d'attente.

```sqf
[_unit] spawn {
    params ["_unit"];
    while { alive _unit && (_unit getVariable ["LL_Task_Status", "WAIT"]) == "WAIT" } do {
        private _players = allPlayers select { alive _x };
        if (count _players > 0) then {
            private _nearest = _players select [
                { _x distance2D _unit }, "ASCEND"
            ] select 0;
            _unit setDir (_unit getDir _nearest);
            _unit setFormDir (_unit getDir _nearest);
        };
        sleep 2;
    };
};
```

### Variable de statut
Toujours attribuer une variable de statut au PNJ principal (`"WAIT"`, `"ACTION"`, `"DONE"`) synchronisée globalement pour permettre aux boucles de s'arrêter proprement.

```sqf
_unit setVariable ["LL_Task_Status", "WAIT", true];
```

---

## 5. Règles des addActions de tâche

### Couleur jaune obligatoire
Les addActions **spécifiques à une tâche** (interaction avec un PNJ, désamorçage, examen d'objet...) utilisent **toujours la couleur jaune** (`#FFFF00`).  
Les addActions permanentes d'escouade/support restent blanches.

```sqf
_unit addAction [
    format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_XX_Action"],
    ...
```

### Distance d'interaction
La condition de visibilité doit inclure une **limite de distance courte** (3 à 5 mètres) pour forcer le joueur à s'approcher physiquement.

```sqf
"alive _target && _this distance _target < 4"
```

### Anti-double déclenchement
Toujours utiliser une variable globale de verrouillage pour éviter qu'un scénario se déclenche deux fois.

```sqf
if (missionNamespace getVariable ["LL_TaskXX_Triggered", false]) exitWith {};
missionNamespace setVariable ["LL_TaskXX_Triggered", true, true];
_target removeAction _id; // Supprimer l'action immédiatement
```

### Architecture client → serveur
L'addAction est sur le **client**, le scénario s'exécute sur le **serveur**.  
Utiliser un paramètre `_mode` pour distinguer initialisation et callback.

```sqf
// Depuis le client (addAction callback) :
["scenario", [_args]] remoteExec ["LL_fnc_taskXX", 2];

// Dans fn_taskXX.sqf (serveur) :
params [["_mode", "init", [""]], ["_args", [], [[]]]];
if (_mode == "scenario") exitWith { ... };
```

---

## 6. Règles des messages et de l'interface

### Assignation des tâches
Il est **strictement interdit** de créer des dialogues personnalisés ou des fichiers `taskXX_dialogues.xml` pour les tâches.
Toutes les tâches utilisent **un seul et unique audio/message** lors de leur assignation :
- **Audio (en anglais)** : "Une nouvelle mission vous est assigné"
- **Texte affiché** : "Lisez votre briefing de tache"

Aucun autre sous-titre de narrateur ou dialogue de PNJ ne doit être généré pour les tâches.

---

## 7. Règles de gestion des tâches

### Création de tâche (Pas de marqueur 3D)
**Interdiction absolue des marqueurs 3D en jeu.** Les marqueurs de tâche ne doivent s'afficher que sur la carte. Le 9ème paramètre de `BIS_fnc_taskCreate` (`show3DMarker`) doit toujours être à `false`.

```sqf
[
    independent,
    ["task_XX_nom"],
    [
        localize "STR_LL_Task_XX_Desc",
        localize "STR_LL_Task_XX_Title",
        localize "STR_LL_Task_XX_Marker"
    ],
    _positionObjectif,
    "AUTOASSIGNED",
    5,
    true,
    "recon", // icône de tâche
    false    // DÉSACTIVE LE MARQUEUR 3D
] call BIS_fnc_taskCreate;
```

### Changement d'état
```sqf
["task_XX_nom", "SUCCEEDED", true] call BIS_fnc_taskSetState;
["task_XX_nom", "FAILED",    true] call BIS_fnc_taskSetState;
```

### Fin de mission : jamais liée à une tâche
**Aucune tâche ne déclenche directement la fin de mission.**  
La fin est initiée par le **joueur lui-même** en demandant l'extraction hélicoptère (`[Hélicoptère] Demander Extraction`).  
Une tâche peut être `SUCCEEDED` ou `FAILED` sans mettre fin à la mission.

L'extraction est le seul événement qui appelle `BIS_fnc_endMission`.

---

## 8. Placement des positions de rendez-vous

### Priorité aux Game Logics `M_Dans_Bat_XXX`
Toujours rechercher les Game Logics `M_Dans_Bat_XXX` placées dans l'éditeur comme positions de spawn PNJ.  
Ces logiques doivent être **à l'intérieur d'un bâtiment**, positionnées en X, Y, Z précis (+ 0.2 en Z).

### Filtres de distance
- Ne jamais sélectionner une position à **moins de 950 mètres** d'un joueur.

### Fallback progressif
Si aucune logique n'est disponible, rechercher un bâtiment aléatoire en élargissant le rayon par paliers (250 → 400 → 550 → 700 → 850 → 1000 m).  
Prévoir toujours une position statique de dernier recours.

---

## 9. Règles de nettoyage

### Supprimer les PNJ et groupes inutilisés
Après la conclusion d'un scénario, toujours supprimer les PNJ en les faisant s'éloigner  puis disparaitre pour éviter la surcharge serveur.

```sqf
{ if (!isNull _x) then { deleteVehicle _x; }; } forEach _units;
deleteGroup _grp;
```

### Supprimer les marqueurs de tâche
Quand un marqueur de tâche n'est plus nécessaire (PNJ localisé, objectif atteint), le supprimer immédiatement.

```sqf
deleteMarker _markerID;
```

---

## 10. Règles de briefing

### Toute tâche a un briefing
Chaque nouvelle tâche doit ajouter au moins une entrée dans le journal du joueur (`createDiaryRecord`) avec :
- Un **titre** (STR_LL_Diary_TaskXX_Title)
- Un **texte** décrivant la mission, les factions en présence et les règles d'engagement (STR_LL_Diary_TaskXX_Text)

### Les entrées journal sont créées en ordre inverse
Arma 3 affiche les `createDiaryRecord` en ordre chronologique inverse.  
Créer d'abord les sections secondaires (contexte, factions), puis la section principale (OPORD) en dernier.

---

## 11. Immersion et rejouabilité

### Comportement ennemi actif
Un groupe ennemi activé ne doit pas rester statique. Implémenter une patrouille des unités autour du lieu de la mission.

### Gardes en patrouille locale
Les gardes d'un PNJ allié doivent patrouiller **aléatoirement autour du lieu de rencontre** (rayon 4–18 m) en mode `LIMITED` / `SAFE`, et non rester figés. 
Les gardes d'un PNJ ennemis doivent patrouiller **aléatoirement autour du lieu de rencontre** (rayon 4–25 m) pas en mode 'SAFE'

### Voix Native Immersive (PNJ)
Pour simuler qu'un PNJ civil, un otage ou un informateur parle dans sa langue natale au moment d'une interaction clé (comme donner des coordonnées), sans utiliser d'animation de dialogue classique, on force le moteur à générer l'audio natif en lui faisant donner un ordre à un "soldat fantôme" temporaire.

**Pattern obligatoire :**
```sqf
// --- VOIX NATIVE IMMERSIVE ---
private _pnjGrp = group _pnj;
private _dummy = _pnjGrp createUnit ["I_G_Soldier_F", getPos _pnj, [], 0, "NONE"];
_dummy hideObjectGlobal true;
_dummy allowDamage false;
_dummy disableAI "ALL";
_pnjGrp selectLeader _pnj;

// Le PNJ "donne un ordre" au fantôme → le moteur génère sa voix native !
_dummy commandMove (getPos _pnj getPos [500, random 360]);

// Laisser le temps au PNJ de prononcer sa phrase (2 à 3 secondes)
sleep 3;
deleteVehicle _dummy; // Nettoyage
```
_Note : Ce code s'exécute sur le serveur et le groupe du PNJ doit être conservé intact le temps que le son soit joué, avant tout changement de camp (`joinSilent`)._

---

## 12. Règles de debug

### Tout log encapsulé dans `DEBUG_MODE`
Aucun `diag_log` ne doit traîner sans condition. Toujours utiliser :

```sqf
if (DEBUG_MODE) then {
    diag_log "[LL] taskXX: message de debug.";
};
```

### Préfixe `[LL]` obligatoire
Tous les logs commencent par `[LL]` suivi du nom de la fonction.

---

## 14. Déplacement et suppression des I.A inutiles de fin de task

### Concept : la fonction globale de nettoyage `LL_fnc_taskCleanup`

À la fin d'une tâche, les IA restantes ne servent plus. Afin d'éviter qu'elles ne se téléportent ou ne soient supprimées de manière visible sous les yeux des joueurs, elles sont traitées de manière unifiée via la fonction `LL_fnc_taskCleanup` appelée avec la liste des unités :

```sqf
[_guards] spawn LL_fnc_taskCleanup;
```

---

### Comportement unifié de la fonction `LL_fnc_taskCleanup` :

1. **Suppression immédiate à plus de 1500m :**
   Toutes les IA (hommes ou véhicules) situées à plus de **1500 mètres** de n'importe quel joueur vivant sont supprimées immédiatement (`deleteVehicle`) pour libérer les ressources du serveur.

2. **IA Ennemies (`east`) à moins de 1500m - Contre-attaque ultra-agressive :**
   Toutes les IA ennemies proches sont réunies et divisées en petits groupes tactiques de **2 ou 3 unités**. Ces groupes sont configurés en comportement combat (`COMBAT`), vitesse maximale (`FULL`), précision élevée, et reçoivent des waypoints dynamiques de recherche et destruction (`SAD`) vers le joueur vivant le plus proche (mis à jour toutes les 10 secondes).

3. **IA Amies ou Civiles (autres camps) à moins de 1500m - Fuite propre :**
   Les IA non-ennemies (comme les villageois ou civils) fuient le secteur vers un **point de dissolution** temporaire calculé à plus de **150m** des joueurs et se suppriment une fois arrivées hors de vue.

---

### Avantages :
- Centralisé dans [fn_taskCleanup.sqf](file:///C:/Users/kevin/Documents/Arma%203/missions/RACS.cup_Zargabad_a3/Functions/Task/fn_taskCleanup.sqf), aucun log de débogage (`diag_log`) n'est utilisé.
- Évite les suppressions visibles à l'écran.
- Crée une tension de fin de mission où les forces ennemies locales convergent immédiatement pour traquer les joueurs.

---

## 13. Conventions de nommage

| Élément | Convention | Exemple |
|---|---|---|
| ID de tâche | `task_XX_nom` | `task_01_recon` |
| Variable de déclenchement | `LL_TaskXX_NomAction` | `LL_Task01_Triggered` |
| Variable de statut PNJ | `LL_Task_Status` | `"WAIT"` / `"ACTION"` / `"DONE"` |
| Clé STR tâche | `STR_LL_Task_XX_*` | `STR_LL_Task_01_Action` |
| Clé STR dialogue | `STR_LL_Task_XX_SY_*` | `STR_LL_Task_01_S1_Chief` |
| Variable globale partagée | `LL_g_nomVariable` | `LL_g_usedTaskPos` |
| Fonction tâche | `LL_fnc_taskXX` | `LL_fnc_task01` |
| Fonction addAction | `LL_fnc_taskXX_addAction` | `LL_fnc_task01_addAction` |
| Fonction de nettoyage | `LL_fnc_taskCleanup` | `LL_fnc_taskCleanup` |

