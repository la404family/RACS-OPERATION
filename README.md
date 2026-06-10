# Architecture de la Mission - Opération RACS (SP & COOP)

Ce document décrit l'architecture des scripts et l'organisation des fichiers pour la mission **RACS.cup_Zargabad_a3**. Conçue spécifiquement pour le Solo (SP) et la Coopération (COOP), cette mission repose sur un framework léger, modulaire et hautement optimisé.

---

## 1. Structure des Fichiers de Base

La racine de la mission respecte scrupuleusement les standards de développement d'Arma 3 (Event Scripts) :

- **`description.ext`** : C'est le cœur de la configuration. Il définit :
  - Les paramètres de base (Nom de la mission, Auteur, Respawns).
  - La gestion des performances (`corpseManager` et `wreckManager` pour nettoyer la carte automatiquement).
  - La bibliothèque de fonctions personnalisées `CfgFunctions` (préfixe `LL_fnc_`).
  - La bibliothèque des sons `CfgSounds` pour l'Ezan.

- **`init.sqf`** : Exécuté partout et avant le lancement final. C'est ici que sont appelées les fonctions serveurs vitales (Météo et Ezan) encapsulées dans un `if (isServer)`. Ce choix d'architecture garantit un fonctionnement irréprochable en mode "Singleplayer" (Éditeur) et en multijoueur.

- **`initServer.sqf`** : Prévu pour les tâches purement dédiées au serveur multijoueur (IA, objectifs, triggers globaux). Actuellement vide suite au portage des fonctions environnementales vers l'`init.sqf` pour la compatibilité SP absolue.

- **`initPlayerLocal.sqf`** : Prévu pour les scripts s'exécutant uniquement sur la machine du joueur local au moment de son apparition en jeu (JIP inclus). Utile pour le briefing, les actions molette (`addAction`), et l'interface utilisateur.

---

## 2. Bibliothèque de Fonctions

Toutes les fonctions sont pré-compilées par le moteur Arma 3 au démarrage de la mission, garantissant une exécution instantanée en jeu sans chargement de fichiers. Le code est expurgé de tout commentaire pour des raisons de performance et de propreté selon les standards du projet.

### Environnement (`Functions\Environment\`)
*   **`fn_randomWeather.sqf` (`LL_fnc_randomWeather`)**
    *   **Rôle :** Génère une météo totalement aléatoire et réaliste à chaque redémarrage de la mission.
    *   **Fonctionnement :** Aléatoirisation de l'heure. Sélection équiprobable via `selectRandom` parmi 8 presets climatiques. Utilise un "Hack" d'horloge (`skipTime`) pour forcer instantanément le changement de ciel.
    *   **Localité :** Exécuté de manière asynchrone côté Serveur (`init.sqf`).
*   **`fn_initSkills.sqf` (`LL_fnc_initSkills`)**
    *   **Rôle :** Exécuté côté serveur. Boucle infinie s'activant toutes les 20 secondes pour auditer l'ensemble des IA de la carte. Ajuste de manière asymétrique les compétences (Sniper/MG/Infanterie) des unités alliées et affaiblit légèrement les unités OPFOR locales. Les compétences sont appliquées une seule fois par unité de manière optimisée.
*   **`fn_playEzan.sqf` (`LL_fnc_playEzan`)**
    *   **Rôle :** Renforce massivement l'immersion en jouant des appels à la prière (Ezan) spatialisés via les haut-parleurs des minarets de la carte.
    *   **Fonctionnement :** Le serveur calcule (avec le très rapide `distanceSqr`) quels joueurs sont à portée (< 2500m) et envoie un `remoteExecCall` pour jouer le son localement en 3D.
*   **`fn_doorSecurity.sqf` (`LL_fnc_doorSecurity`)**
    *   **Rôle :** Exécuté côté serveur. Gère dynamiquement l'ouverture et la fermeture des portes pour les IA ennemies et civiles (non-BLUFOR).
    *   **Fonctionnement :** Scanne les bâtiments proches des IA. Ouvre de manière anticipée et fluide les portes sur leur chemin en jouant un son localisé, et les referme après un délai (12s). Empêche les bots de traverser les murs fermés et améliore drastiquement l'immersion des combats urbains.

### Joueurs (`Functions\Player\`)
*   **`fn_initIdentity.sqf` (`LL_fnc_initIdentity`)**
    *   **Rôle :** Exécuté par le serveur. Assigne dynamiquement un nom complet, un type de visage (Africain, Arabe, Asiatique, Pacifique, Européen) et une voix native anglaise (Arma 3 Vanilla) à chaque joueur de l'escouade.
*   **`fn_applyIdentity.sqf` (`LL_fnc_applyIdentity`)**
    *   **Rôle :** Applique techniquement (`setFace`, `setName`, `setSpeaker`, `setPitch`) l'identité transmise par le serveur de manière purement locale.
*   **`fn_initLoadout.sqf` (`LL_fnc_initLoadout`)**
    *   **Rôle :** Orchestrateur serveur. Collecte les unités joueurs (`player_00` à `player_99`), puis pour chacune tire au hasard (`selectRandom`) un uniforme, gilet, sac, casque et cagoule parmi les listes définies (voir `INFO.md`). Transmet le résultat au client propriétaire via `remoteExec` ou l'applique directement si l'unité est locale (mode SP).
    *   **Équipement randomisé :** Uniformes USMC désert (12 variantes), gilets JPC Coyote (9 variantes), casques OpsCore (6 variantes), sacs à dos (3 variantes), cagoules/lunettes (10 variantes).
*   **`fn_applyLoadout.sqf` (`LL_fnc_applyLoadout`)**
    *   **Rôle :** Exécuté localement sur le client propriétaire de l'unité. Procède à un strip total de l'unité (`removeAllWeapons`, `removeAllItems`, `removeAllAssignedItems`, suppression de chaque conteneur) puis reconstruit tout de zéro : conteneurs → magazines (5 primaires, 3 pistolet) → grenades M67 (×2) → fumigènes blancs (×2) → soins (×3) → armes avec accessoires → jumelles CUP_LRTV → NVG → items assignés (carte, boussole, montre, radio).
    *   **Mécanisme clé :** Les armes et accessoires sont lus localement (`primaryWeapon`, `primaryWeaponItems`) *avant* le strip, puis ré-appliqués après la mise en place des conteneurs, garantissant que les magazines disposent d'un espace d'inventaire réel.
*   **`fn_initLocal.sqf` (`LL_fnc_initLocal`)**
    *   **Rôle :** Exécuté par le client (`initPlayerLocal.sqf`). Initialise le Briefing (Diary) et attend la réception de l'identité envoyée par le serveur avant de l'appliquer localement.
*   **`fn_addRallyAction.sqf` (`LL_fnc_addRallyAction`)**
    *   **Rôle :** Exécuté localement. Ajoute une action molette blanche "Regroupement IA" au chef d'escouade. L'action n'est visible que s'il y a des IA d'infanterie (hors véhicules) dans le groupe.
*   **`fn_forceRally.sqf` (`LL_fnc_forceRally`)**
    *   **Rôle :** Outil de déblocage (unstuck) agressif pour l'IA. Réinitialise le comportement des bots (`enableAI "ALL"`, `setUnitPos "AUTO"`, `doStop`), force une formation en colonne compacte, puis donne un double ordre de déplacement (`commandMove` + `moveTo`) vers une position calculée et "sûre" près du leader. Une boucle surveille les bots toujours coincés (>12m, vitesse nulle) et tente des micro-déplacements de déblocage latéraux avant de relancer l'ordre `doFollow`.
*   **`fn_addHealAction.sqf` (`LL_fnc_addHealAction`)**
    *   **Rôle :** Exécuté localement. Ajoute une action molette verte "Soin Automatique IA" au chef d'escouade. Vérifie l'état de santé de toutes les IA du groupe. Si blessées et équipées de FirstAidKit, l'IA se met à genou, stoppe ses mouvements et se soigne automatiquement de manière forcée avant de reprendre sa place. Affiche "Négatif" si manque de matériel.
*   **`fn_addSearchAction.sqf` (`LL_fnc_addSearchAction`)**
    *   **Rôle :** Exécuté localement. Ajoute une action molette jaune pour ordonner à son escouade IA de fouiller les bâtiments proches. L'action est conditionnée par la présence de bâtiments à moins de 55m et la présence d'infanterie IA sous les ordres du leader.
    *   **Fonctionnement :** Génère un marqueur de zone jaune sur la carte (respectant la transparence standard), joue une animation synchronisée en multijoueur (`remoteExec`), puis déploie les IA de manière agressive (`AWARE`, `FULL`, `YELLOW`) vers les positions intérieures. Inclut un système d'anti-stuck par unité et un délai maximal d'opération de 3 minutes avant de reprendre la formation automatiquement.
*   **`fn_assignLeader.sqf` (`LL_fnc_assignLeader`)**
    *   **Rôle :** Exécuté par le serveur. Boucle de surveillance continue garantissant qu'un joueur humain garde toujours le commandement de l'escouade.
    *   **Fonctionnement :** Rapatrie automatiquement les joueurs éparpillés dans le groupe principal (`player_00`). Si le leader devient une I.A (suite à une mort ou déconnexion), le script réassigne instantanément le lead au premier joueur humain disponible et en notifie l'escouade.
*   **`fn_addRoeActions.sqf` (`LL_fnc_addRoeActions`)**
    *   **Rôle :** Exécuté localement. Ajoute un menu molette dynamique permettant au chef d'escouade de dicter les Règles d'Engagement (RoE) de ses IA.
    *   **Fonctionnement :** Propose 7 comportements tactiques distincts (Infiltration, Patrouille, Vigilance, Assaut, Charge, Défense, Reset) affectant simultanément la formation, la vitesse, l'attitude de combat (`AWARE`, `COMBAT`, `STEALTH`) et la posture (`UP`, `AUTO`). Inclut un feedback visuel coloré et textuel, et se maintient après chaque réapparition via une boucle locale.
*   **`fn_setupUVO.sqf` (`LL_fnc_setupUVO`)**
    *   **Rôle :** Exécuté dynamiquement à la création d'une unité. Assure la compatibilité totale et automatique avec le mod audio *Unit Voice-Overs (UVO)* s'il est activé.
    *   **Fonctionnement :** Force la langue des joueurs RACS en Anglais, et la langue des ennemis/civils (OPFOR/Civil) aléatoirement en Arabe ou en Perse. Bloque les systèmes de détection automatique du mod pour éviter les conflits d'assignation.

### Civils (`Functions\Civilian\`)
*   **`fn_initCivilians.sqf` (`LL_fnc_initCivilians`)**
    *   **Rôle :** Initialisation serveur du système civil complet. Construit les bases de données de noms perses/afghans (146 hommes, 130+ femmes), les pools visuels (visages, couvre-chefs CUP, barbes) et les 24 loadouts bandits. Collecte les templates placés dans l'éditeur (`template_01` à `template_XX` + `Max_Tak_woman*`) via `getUnitLoadout`, puis les supprime de la carte. Installe le gestionnaire `EntityCreated` pour appliquer les templates aux spawns futurs.
    *   **Convention de genre :** `template_01` à `template_16` = femmes (détection par `"woman"` dans la classe). `template_17+` = hommes. Les hommes reçoivent barbe (`CUP_Beard_Brown`/`Black`) + couvre-chef CUP aléatoire. Les femmes ont un pitch voix plus élevé (1.3–1.4).
*   **`fn_applyTemplate.sqf` (`LL_fnc_applyTemplate`)**
    *   **Rôle :** Applique un template civil à une unité non-joueur, non-indépendante. Utilise `setUnitLoadout` pour la tenue complète. Les OPFOR/BLUFOR reçoivent en plus un armement bandit avec lampe tactique forcée. L'identité (nom + visage + voix native perse) est diffusée à tous les clients via `remoteExec`. Le script déclenche également `LL_fnc_setupUVO` pour le support éventuel des voix arabes HD.
*   **`fn_spawnPresence.sqf` (`LL_fnc_spawnPresence`)**
    *   **Rôle :** Boucle infinie serveur gérant la présence civile dynamique. Spawne des civils dans les bâtiments proches des joueurs (rayon 500m, minimum 50m) et supprime ceux au-delà de 1200m. Maximum 55 civils simultanés. Chaque civil reçoit un template et une patrouille aléatoire.
*   **`fn_manageInsurgents.sqf` (`LL_fnc_manageInsurgents`)**
    *   **Rôle :** Boucle infinie serveur gérant le système de "Sleeper Cells" (cellules dormantes).
    *   **Fonctionnement :** Convertit de manière transparente et aléatoire des civils éloignés (300-450m) en insurgés hostiles (OPFOR). Utilise un changement de camp invisible (`joinSilent`) pour que le civil conserve exactement son modèle 3D, ses vêtements civils et sa voix UVO. Pioche ensuite aléatoirement un sac et une arme dans la banque `MISSION_BanditLoadouts` avant de lancer un ordre d'assaut (SAD) sur l'escouade du joueur.

### Drone (`Functions\Drone\`)
*   **`fn_addDroneAction.sqf` (`LL_fnc_addDroneAction`)**
    *   **Rôle :** Client uniquement. Ajoute une action molette blanche « Demander un drone de surveillance » au chef d'escouade. Au clic, ouvre la carte pour sélectionner la zone cible. Se réapplique automatiquement après un respawn ou un switch d'unité IA.
*   **`fn_requestDrone.sqf` (`LL_fnc_requestDrone`)**
    *   **Rôle :** Serveur uniquement. Spawne un MQ-9 Reaper (`CUP_B_USMC_DYN_MQ9`) à 350m d'altitude, le fait orbiter autour de la zone ciblée (LOITER, rayon 400m). Crée 3 marqueurs carte : zone de surveillance (ellipse bleue), icône aérienne fixe, et position temps-réel du drone (mise à jour toutes les 2s). Durée de mission : 5 minutes. Cooldown de 2 minutes après le retour à la base. Nettoyage automatique (drone + crew + marqueurs + groupe).

---

## 3. Normes de Code & Bonnes Pratiques

- **Zéro Commentaire in-game :** Les fichiers `.sqf` ont été expurgés de tout commentaire afin de réduire (bien que de manière marginale) la taille des fichiers envoyés sur le réseau lors de la connexion des joueurs et pour conserver un code strictement minimaliste. La documentation est centralisée ici.
- **Performances Réseau :** L'usage exclusif de `remoteExecCall` (pas de suspension d'environnement) et la séparation Serveur/Local (`init` vs `apply`) assurent une synchronisation sans faille en multijoueur tout en supportant les connexions tardives (JIP).
# RACS-OPERATION
