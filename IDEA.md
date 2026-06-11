# IDEA.md — Idées de missions pour le dossier `Task/`

Toutes les idées ci-dessous respectent les règles de `TASK_RULES.md` :
- Logique serveur dans `fn_taskXX.sqf`, addActions client dans `fn_taskXX_addAction.sqf`
- Positions via les logiques `M_Dans_Bat_XXX` (distance > 250m des joueurs)
- Pas de marqueur 3D, pas de fin de mission dans la tâche
- Un seul message à l'assignation : "Lisez votre briefing de tâche"
- Nettoyage des PNJ et marqueurs après conclusion

---

## TASK 03 — Cache d'armes

**Résumé :** Des caches d'armes insurgées sont dissimulées dans des bâtiments du secteur. Localiser et détruire chaque cache.

**Logique :**
1. Spawn de 2–3 objets "caisse" (`Box_East_Wps_F`) à des positions `M_Dans_Bat_` distinctes.
2. Chaque caisse est gardée par 3–5 ennemis en patrouille locale.
3. `addAction` jaune sur chaque caisse : `"Poser une charge"` → délai de 10 secondes → `setDamage 1` + explosion (`BIS_fnc_fire`).
4. Variable de comptage : quand toutes les caisses sont détruites → `SUCCEEDED`.

**Variante rejouable :** Nombre de caisses aléatoire (2 à 4), position aléatoire à chaque lancement.

---

## TASK 04 — Patrouille disparue

**Résumé :** Une patrouille RACS ne répond plus. Localiser les survivants et les ramener à un point de ralliement.

**Logique :**
1. Spawn de 2 groupes : un groupe de soldats RACS (BLUFOR, 2–3 unités) blessés/désarmés et un groupe ennemi à proximité.
2. Les soldats RACS sont en animation d'attente (`Acts_CivilSitting_1`), variable `LL_Task_Status = "WAIT"`.
3. `addAction` jaune sur chaque soldat : `"Ordonner de suivre"` → l'unité rejoint le groupe joueur (`joinSilent`).
4. Un marqueur "point de ralliement" est créé sur la carte (position statique ou logique dédiée).
5. Condition de succès : tous les survivants sont vivants dans un rayon de 30m du point de ralliement.

**Note :** Les soldats RACS ne combattent pas avant d'être "récupérés" (`disableAI "MOVE"` levé après l'action).

---

## TASK 05 — Récupération de véhicule

**Résumé :** Un véhicule militaire RACS est immobilisé en zone hostile. Atteindre le véhicule, le réparer et le ramener à un dépôt.

**Logique :**
1. Spawn d'un véhicule endommagé (`setDamage 0.8`) à une position `M_Dans_Bat_` (ou position statique aléatoire sur route).
2. Zone défendue par 4–6 ennemis en patrouille.
3. `addAction` jaune sur le véhicule : `"Réparer le véhicule"` (condition : joueur < 3m, `toolKit` dans l'inventaire) → animation `Acts_UnconsciousStandUp_nonSterile` + délai 8s → `setDamage 0`.
4. Un marqueur "dépôt" apparaît sur la carte (position fixe en zone sécurisée).
5. Condition de succès : le véhicule entre dans un trigger de rayon 50m autour du dépôt.

---

## TASK 06 — Élimination d'un HVT en mouvement

**Résumé :** Un chef insurgé se déplace entre des positions dans la ville. Identifier et neutraliser la cible avant qu'elle ne s'échappe.

**Logique :**
1. Spawn du HVT (chef) avec 2 gardes du corps qui patrouillent un itinéraire de 3–4 waypoints en boucle (`CYCLE`).
2. Le HVT ressemble visuellement à un civil (template civil + arme) pour forcer l'identification.
3. Une fausse cible identique (même modèle, différent `netId`) est spawné dans une autre zone — le joueur doit tuer le bon.
4. `addAction` jaune : `"Fouiller le corps"` (post mortem, distance < 3m) → indique si c'est le bon HVT via `systemChat`.
5. Succès : fouille confirmée sur le bon corps. Échec : fausse cible fouillée (tâche `FAILED`, message d'erreur).

**Indicateur :** Un seul marqueur zone sur la carte (ellipse large), pas de marqueur sur le HVT lui-même.

---

## TASK 07 — Défense de position

**Résumé :** Tenir une position clé (bâtiment ou carrefour) contre plusieurs vagues d'assaut ennemies.

**Logique :**
1. Un marqueur "zone à défendre" (ellipse verte, rayon 40m) est créé sur la carte à une position statique.
2. Timer visible : `progressLoadingScreen` ou `systemChat` toutes les 30s avec le temps restant (ex : 5 minutes totales).
3. Toutes les 90 secondes : spawn d'un groupe ennemi (4–8 unités) avec `COMBAT` / `AWARE` qui converge vers la zone.
4. Condition de succès : au moins un joueur vivant dans la zone à l'expiration du timer.
5. Condition d'échec : aucun joueur dans la zone pendant plus de 20 secondes consécutives.

**Note :** Les ennemis des vagues précédentes ne sont pas supprimés, ils s'accumulent pour augmenter la pression.

---

## TASK 08 — Informateur à exfiltrer

**Résumé :** Un informateur civil veut passer à l'Ouest. L'escorter à pied jusqu'à un point d'extraction discret sans attirer l'attention.

**Logique :**
1. Spawn d'un civil (template civil, sans arme) à une position `M_Dans_Bat_`. Variable statut `"WAIT"`.
2. `addAction` jaune : `"Parler à l'informateur"` → le civil rejoint silencieusement le groupe joueur et commence à marcher (`doFollow`).
3. Des patrouilles ennemies circulent sur la route (comportement `SAFE` jusqu'au contact).
4. Point d'extraction : position fixe sur la carte (marqueur discret, icône `flag`).
5. Condition de succès : le civil entre vivant dans le trigger d'extraction (rayon 20m).

**Mécanisme voix natif :** À l'interaction, le civil utilise le pattern "voix native immersive" (dummy soldier) pour simuler une réponse en perse.

---

## TASK 09 — Saisie de matériel de propagande

**Résumé :** Des équipements de diffusion (radio insurgée, imprimerie) sont installés dans un bâtiment. Les détruire tous.

**Logique :**
1. Spawn de 3–4 objets `Land_Laptop_unfolded_F` (ou similaire) à des positions `M_Dans_Bat_` à l'intérieur du même bâtiment.
2. Le bâtiment est défendu par 5–7 gardes.
3. `addAction` jaune sur chaque objet : `"Détruire l'équipement"` → `setDamage 1` + son `explosion`.
4. Compteur affiché en `systemChat` après chaque destruction : `"X/3 équipements détruits"`.
5. Succès quand tous les objets sont détruits.

**Avantage :** Toute la logique est dans un seul bâtiment — combat CQB concentré, tâche rapide (5–10 min).

---

## TASK 10 — Sniper en position exposée

**Résumé :** Un tireur d'élite RACS est en position mais cerné. Dégager la zone et lui signaler qu'il peut se retirer.

**Logique :**
1. Spawn d'un soldat RACS sniper (`I_Sniper_F`) couché sur un toit ou à une fenêtre, immobilisé (`disableAI "MOVE"`).
2. Des ennemis convergent sur sa position depuis plusieurs axes.
3. Condition de "zone sécurisée" : aucun ennemi vivant dans un rayon de 80m du sniper pendant 15 secondes.
4. `addAction` jaune sur le sniper : `"Donner le signal de retrait"` (visible uniquement quand zone sécurisée) → sniper rejoint le groupe ou se dirige vers un waypoint de repli.
5. Succès : signal envoyé ET sniper vivant.

---

## TASK 11 — Checkpoint insurgé à neutraliser

**Résumé :** Un checkpoint illégal bloque une route principale. Neutraliser les insurgés et détruire le barrage.

**Logique :**
1. Spawn de 2 véhicules barrage (`Land_BarGate_F` ou épave) et de 6–8 ennemis répartis autour.
2. Les ennemis sont en mode `SAFE` jusqu'au premier contact (simulation de checkpoint actif).
3. `addAction` jaune sur chaque véhicule barrage : `"Dégager l'obstacle"` (condition : tous les ennemis à moins de 50m sont morts) → `setDamage 1`.
4. Succès : les deux barrages détruits.

**Optionnel :** Un chef de checkpoint (HVT mineur) avec un objet "radio" → `addAction "Saisir la radio"` donne la position d'une cache d'armes (info bonus, pas de nouvelle tâche).

---

## Notes d'implémentation communes

| Règle | Rappel |
|---|---|
| Spawn PNJ | Z + 0.2 + `allowDamage false` pendant 3s |
| Distance spawn | > 250m de tous les joueurs vivants |
| addActions de tâche | Couleur jaune `#FFFF00`, distance < 4m |
| Anti double-déclenchement | `missionNamespace setVariable ["LL_TaskXX_Triggered", false]` |
| Nettoyage | `deleteVehicle` + `deleteGroup` + `deleteMarker` après conclusion |
| Marqueurs 3D | **Toujours désactivés** (`false` en 9ème param de `BIS_fnc_taskCreate`) |
| Fin de mission | **Jamais dans une tâche** — uniquement via l'extraction hélicoptère |
