# BUG — La demande de tâche déclenche les sélecteurs de position Hélicoptère & Drone

## Description du symptôme

Lorsque le joueur (Chef d'escouade) utilise l'action molette **"Demander une tâche"**, le
jeu ouvre la carte et lui demande successivement de cliquer pour positionner l'hélicoptère
**et** le drone, au lieu de simplement déclencher une tâche aléatoire.

---

## Fichiers concernés

| Fichier | Rôle |
|---|---|
| `Functions/Task/fn_addTaskAction.sqf` | Enregistre l'action "Demander une tâche" sur le joueur |
| `Functions/Helicopter/fn_addHelicopterActions.sqf` | Enregistre les 5 actions hélicoptère (dont EMBARQUEMENT) |
| `Functions/Drone/fn_addDroneAction.sqf` | Enregistre l'action de surveillance drone |

---

## Cause racine n°1 — Collision de priorité d'`addAction`

### Ce qui se passe

Dans Arma 3, le paramètre `priority` de `addAction` détermine la position de l'entrée
dans la roue de sélection (scroll wheel). **Deux actions avec la même priorité sur la
même unité apparaissent dans un ordre non-déterministe**, qui peut changer d'une session
à l'autre ou après un JIP.

### Valeurs en conflit

```
fn_addTaskAction.sqf        → "Demander une tâche"  priority = 7.5  ← COLLISION
fn_addHelicopterActions.sqf → "EMBARQUEMENT"        priority = 7.5  ← COLLISION
```

**Tableau complet des priorités d'actions du Chef :**

| Priorité | Action | Fichier source |
|---|---|---|
| `8.0` | Drone Surveillance | `fn_addDroneAction.sqf` |
| `7.9` | Ravitaillement (LIVRAISON) | `fn_addHelicopterActions.sqf` |
| `7.8` | Largage Véhicule (VEHICULE) | `fn_addHelicopterActions.sqf` |
| `7.7` | Appui Feu (CAS) | `fn_addHelicopterActions.sqf` |
| `7.6` | Débarquement (DEBARQUEMENT) | `fn_addHelicopterActions.sqf` |
| `7.5` | **⚠ Extraction (EMBARQUEMENT)** | `fn_addHelicopterActions.sqf` |
| `7.5` | **⚠ Demander une tâche** | `fn_addTaskAction.sqf` |

### Conséquence directe

Le joueur, cherchant à cliquer sur **"Demander une tâche"**, clique en réalité sur
**"EMBARQUEMENT"** (ou inversement selon l'ordre affiché). L'action EMBARQUEMENT appelle
`_fnc_requestWithMap` qui :
1. Ouvre la carte (`openMap true`)
2. Enregistre un handler `MapSingleClick` pour capter la position de dépose hélico
3. Affiche un message radio demandant de cliquer sur la carte

Le joueur pense avoir demandé une tâche mais a en fait initié une demande d'extraction.

---

## Cause racine n°2 — Handlers `MapSingleClick` orphelins (non-nettoyés)

### Ce qui se passe

`fn_addHelicopterActions.sqf` et `fn_addDroneAction.sqf` utilisent tous les deux le
pattern suivant :

```sqf
// Dans fn_addHelicopterActions.sqf (_fnc_requestWithMap)
openMap true;
missionNamespace setVariable ["LL_Heli_MapClick", true];
addMissionEventHandler ["MapSingleClick", {
    if !(missionNamespace getVariable ["LL_Heli_MapClick", false]) exitWith {};
    missionNamespace setVariable ["LL_Heli_MapClick", false];
    removeMissionEventHandler ["MapSingleClick", _thisEventHandler];  // ← supprimé SEULEMENT si on clique
    ...
}];

// Dans fn_addDroneAction.sqf
openMap true;
LL_Drone_MapClick = true;
addMissionEventHandler ["MapSingleClick", {
    if !(LL_Drone_MapClick) exitWith {};
    LL_Drone_MapClick = false;
    removeMissionEventHandler ["MapSingleClick", _thisEventHandler];  // ← supprimé SEULEMENT si on clique
    ...
}];
```

**Le handler `MapSingleClick` n'est supprimé que si l'utilisateur clique sur la carte.**

### Que se passe-t-il si le joueur appuie sur Échap ?

| Élément | État après Échap |
|---|---|
| Carte | Fermée |
| `LL_Heli_MapClick` | Reste à `true` |
| `LL_Drone_MapClick` | Reste à `true` |
| Handler `MapSingleClick` hélico | **Toujours actif** |
| Handler `MapSingleClick` drone | **Toujours actif** |

De plus, `addMissionEventHandler` n'effectue **aucune vérification** d'unicité : chaque
tentative avortée **empile un nouveau handler** sur les handlers précédents. Après N
tentatives avortées, N handlers `MapSingleClick` sont enregistrés simultanément.

### Conséquence directe

La prochaine ouverture de carte (quelle qu'en soit la raison) déclenche **tous les
handlers en attente**, simulant autant de demandes fantômes d'hélicoptère et/ou de drone.

---

## Scénario de reproduction du bug

1. Le joueur ouvre la roue d'action. Les entrées "EMBARQUEMENT" (hélico) et "Demander une
   tâche" se trouvent **à la même position** (priorité 7.5).
2. Le joueur clique sur ce slot en croyant demander une tâche. Il clique en réalité sur
   "EMBARQUEMENT" → la carte s'ouvre, un handler `MapSingleClick` hélico est enregistré,
   `LL_Heli_MapClick = true`.
3. Le joueur réalise son erreur et appuie sur **Échap** pour fermer la carte. Le handler
   hélico reste actif.
4. Le joueur rouvre la roue et clique sur "Drone Surveillance" (8.0) par inadvertance, ou
   l'a déjà fait lors d'une précédente session → un handler drone est enregistré,
   `LL_Drone_MapClick = true`.
5. Le joueur appuie à nouveau sur **Échap**. Le handler drone reste actif.
6. Le joueur clique correctement sur **"Demander une tâche"** → `["REQUEST"] remoteExec
   ["LL_fnc_taskManager", 2]` s'exécute correctement sur le serveur.
7. Cependant, les handlers orphelins des étapes 2–5 sont **toujours en attente**. La
   prochaine fois que la carte est ouverte (toute raison), le handler hélico se déclenche
   sur le premier clic (demande d'extraction fantôme), puis le handler drone sur le
   second clic (surveillance fantôme). Le joueur voit les messages radio correspondants.

---

## Corrections recommandées

### Fix 1 — Résoudre la collision de priorité (immédiat, une ligne)

Dans `Functions/Task/fn_addTaskAction.sqf`, ligne ~16, changer la priorité de `7.5` à
une valeur unique non utilisée, par exemple `7.45` :

```sqf
// AVANT
_unit addAction [..., nil, 7.5, false, true, "", ...];

// APRÈS
_unit addAction [..., nil, 7.45, false, true, "", ...];
```

### Fix 2 — Nettoyer les handlers quand la carte est fermée par Échap

Remplacer le `addMissionEventHandler` passif par un thread qui surveille `visibleMap` et
annule la demande si la carte est fermée sans clic.

**Exemple pour `fn_addHelicopterActions.sqf` (`_fnc_requestWithMap`) :**

```sqf
private _fnc_requestWithMap = {
    params ["_type"];
    // ... gardes existantes ...

    openMap true;
    ["STR_LL_Heli_Action_ClickMap"] call LL_fnc_radioMessage;
    missionNamespace setVariable ["LL_Heli_MapClick", true];
    missionNamespace setVariable ["LL_Heli_PendingType", _type];

    private _ehId = addMissionEventHandler ["MapSingleClick", {
        params ["_units", "_pos", "_alt", "_shift"];
        if !(missionNamespace getVariable ["LL_Heli_MapClick", false]) exitWith {};
        missionNamespace setVariable ["LL_Heli_MapClick", false];
        removeMissionEventHandler ["MapSingleClick", _thisEventHandler];
        openMap false;
        private _type = missionNamespace getVariable ["LL_Heli_PendingType", ""];
        [_type, _pos, player] remoteExec ["LL_fnc_requestHelicopter", 2];
        ["STR_LL_Heli_Action_EnRoute", [round (_pos select 0), round (_pos select 1), _type]] call LL_fnc_radioMessage;
    }];

    // NOUVEAU : thread de surveillance fermeture carte par Échap
    [_ehId] spawn {
        params ["_ehId"];
        waitUntil { sleep 0.2; !visibleMap || !(missionNamespace getVariable ["LL_Heli_MapClick", false]) };
        if (missionNamespace getVariable ["LL_Heli_MapClick", false]) then {
            // Carte fermée par Échap sans clic → nettoyage
            missionNamespace setVariable ["LL_Heli_MapClick", false];
            removeMissionEventHandler ["MapSingleClick", _ehId];
        };
    };
};
```

**Le même pattern doit être appliqué dans `fn_addDroneAction.sqf`** pour `LL_Drone_MapClick`.

### Fix 3 — Empêcher l'accumulation de handlers (défense en profondeur)

Avant d'ajouter un nouveau handler, annuler toute requête hélico/drone en attente :

```sqf
// En tête de _fnc_requestWithMap
if (missionNamespace getVariable ["LL_Heli_MapClick", false]) then {
    missionNamespace setVariable ["LL_Heli_MapClick", false];
    // Le thread de surveillance du fix 2 s'occupera de supprimer l'ancien handler
};
```

---

## Priorité de correction

| Fix | Impact | Complexité | Priorité |
|---|---|---|---|
| Fix 1 (priorité 7.45) | Élimine la confusion dans le menu | Triviale (1 ligne) | **HAUTE** |
| Fix 2 (cleanup Échap) | Élimine les handlers orphelins | Moyenne | **HAUTE** |
| Fix 3 (guard doublon) | Sécurité supplémentaire | Faible | Moyenne |

Le **Fix 1 seul** réduit significativement les chances de rencontrer le bug. Le
**Fix 2** est nécessaire pour l'éliminer complètement.
