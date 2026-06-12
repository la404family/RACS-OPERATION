# Rapport d'Audit et d'Analyse du Code SQF

Ce rapport présente une analyse détaillée des scripts SQF et des fichiers de configuration de la mission **Opération RACS** située dans le dossier [RACS.cup_Zargabad_a3](file:///C:/Users/kevin/Documents/Arma%203/missions/RACS.cup_Zargabad_a3).

---

## 1. Bugs Critiques et Dysfonctionnements Majeurs

### 🔴 Utilisation d'une commande inexistante (`hashValue`)
* **Fichier concerné** : [fn_doorSecurity.sqf](file:///C:/Users/kevin/Documents/Arma%203/missions/RACS.cup_Zargabad_a3/Functions/Environment/fn_doorSecurity.sqf#L40)
* **Problème** : La ligne `private _bldgKey = hashValue _bldg;` tente d'appeler `hashValue`, qui n'est **pas** une commande native de l'extension SQF d'Arma 3. Cela provoquera une erreur de script immédiate et plantera la boucle de sécurité des portes.
* **Solution** : Depuis Arma 3 version 2.00, les HashMaps acceptent directement les objets comme clés. Vous pouvez simplement faire :
  ```sqf
  private _bldgKey = _bldg; // L'objet lui-même sert de clé dans le HashMap
  ```
  Ou, si vous préférez une chaîne de caractères unique, utilisez `netId _bldg` ou `str _bldg`.

### 🔴 Double exécution des scripts d'initialisation sur le serveur
* **Fichiers concernés** : [init.sqf](file:///C:/Users/kevin/Documents/Arma%203/missions/RACS.cup_Zargabad_a3/init.sqf#L1-L15) et [initServer.sqf](file:///C:/Users/kevin/Documents/Arma%203/missions/RACS.cup_Zargabad_a3/initServer.sqf)
* **Problème** : Les scripts `LL_fnc_randomWeather` et `LL_fnc_initCivilians` sont appelés à la fois dans le bloc `isServer` de `init.sqf` ET directement dans `initServer.sqf`. Par conséquent, le serveur génère deux fois la météo et initialise deux fois le système civil, ce qui peut causer des conflits ou des doubles spawns.
* **Solution** : Supprimez ces appels de l'un des deux fichiers (il est recommandé de tout centraliser dans `initServer.sqf` pour les scripts exclusivement côté serveur).

### 🔴 Risque de JIP Bug (Joueur en cours de connexion)
* **Fichier concerné** : [fn_initLocal.sqf](file:///C:/Users/kevin/Documents/Arma%203/missions/RACS.cup_Zargabad_a3/Functions/Player/fn_initLocal.sqf#L9-L15)
* **Problème** : Le script définit la variable locale `_playerUnit = vehicle player;` au tout début. Si un joueur se connecte en JIP, sélectionne son rôle ou est en cours de chargement, `player` peut renvoyer `objNull` ou une entité temporaire. Le script va ensuite attendre (`waitUntil`) sur cet objet obsolète, ce qui provoquera un timeout de 30 secondes et empêchera l'application de l'identité du joueur.
* **Solution** : Évaluez dynamiquement le joueur à l'intérieur de la condition d'attente :
  ```sqf
  waitUntil {
      sleep 0.5;
      _timeout = _timeout + 0.5;
      (!isNull player && {!isNil { player getVariable "LL_s_identity" }}) || { _timeout >= 30 }
  };
  private _playerUnit = player;
  ```

---

## 2. Optimisations et Bonnes Pratiques

### ⚡ Utilisation de `nearObjects` plutôt que `nearestObjects`
* **Fichier concerné** : [fn_doorSecurity.sqf](file:///C:/Users/kevin/Documents/Arma%203/missions/RACS.cup_Zargabad_a3/Functions/Environment/fn_doorSecurity.sqf#L34)
* **Problème** : La boucle vérifie les bâtiments proches de chaque IA avec `nearestObjects`. Cette commande trie les objets par distance, ce qui est lourd en calculs lorsque répété toutes les 0.8 secondes pour de nombreuses unités.
* **Solution** : Utilisez `nearObjects`, qui est beaucoup plus rapide car elle ne trie pas les résultats par distance :
  ```sqf
  // Remplacer :
  nearestObjects [_pos, ["House", "Building"], _OPEN_DIST + 8]
  // Par :
  _pos nearObjects ["House", _OPEN_DIST + 8] // "House" englobe "Building" dans la hiérarchie des classes
  ```

### 🔊 Simplification de la diffusion du son (Ezan)
* **Fichier concerné** : [fn_playEzan.sqf](file:///C:/Users/kevin/Documents/Arma%203/missions/RACS.cup_Zargabad_a3/Functions/Environment/fn_playEzan.sqf)
* **Problème** : Le serveur filtre les joueurs à portée pour leur envoyer un `remoteExecCall` qui joue le son localement. Or, la commande `say3D` est nativement globale et gère elle-même l'atténuation sonore en 3D en fonction de la distance. Si deux joueurs sont proches du minaret, le code actuel risque de jouer le son plusieurs fois (duplication).
* **Solution** : Laissez le serveur exécuter `say3D` directement de manière globale toutes les 30 minutes. L'architecture réseau d'Arma 3 s'occupera d'envoyer le son aux clients à portée :
  ```sqf
  while {true} do {
      {
          _x say3D ["ezan", 2500, 1];
      } forEach _minarets;
      sleep 1800;
  };
  ```

### ⚡ Amélioration de la syntaxe des HashMaps
* **Fichier concerné** : [fn_requestDrone.sqf](file:///C:/Users/kevin/Documents/Arma%203/missions/RACS.cup_Zargabad_a3/Functions/Drone/fn_requestDrone.sqf#L90)
* **Problème** : La condition `_id in keys _enemyMarkers` force Arma 3 à créer un tableau temporaire contenant toutes les clés du HashMap pour vérifier l'existence de la clé, ce qui est inefficace.
* **Solution** : Utilisez directement l'opérateur `in` sur le HashMap, ce qui est optimisé par le moteur du jeu :
  ```sqf
  if !(_id in _enemyMarkers) then { ... }
  ```
  De plus, la ligne `private _id = str (netId _x);` est redondante car `netId` retourne déjà un type String. Vous pouvez simplement utiliser `private _id = netId _x;`.

### 👥 Limitation du nombre de groupes (Group Limit)
* **Fichier concerné** : [fn_spawnPresence.sqf](file:///C:/Users/kevin/Documents/Arma%203/missions/RACS.cup_Zargabad_a3/Functions/Civilian/fn_spawnPresence.sqf#L63)
* **Problème** : Pour chaque civil généré, le script crée un nouveau groupe (`createGroup civilian`). Arma 3 possède une limite absolue de groupes par côté (288). Si les civils apparaissent et disparaissent fréquemment, cela peut saturer le moteur réseau.
* **Solution** : Regroupez les civils dans un nombre restreint de groupes existants ou réutilisez des groupes vides pour économiser les ressources système.

---

## 3. Architecture et Points Forts du Projet

* **Modularité** : Le projet est très bien structuré. La séparation par dossiers de fonctionnalités (Civilian, Helicopter, UI, Player, Task) et l'utilisation de `CfgFunctions` facilitent grandement la maintenance.
* **Système de traduction dynamique** : L'utilisation d'un script Python (`compile_stringtable.py`) pour assembler automatiquement les fichiers XML locaux dans un seul `stringtable.xml` global est une excellente pratique pour l'organisation du projet.
* **Immersion sonore** : La gestion des appels à la prière (Ezan) et des dialogues radio TTS ajoute une plus-value immersive unique à la mission.
