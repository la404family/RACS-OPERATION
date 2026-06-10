# Analyse et Plan d'Implémentation - Gestion d'Hélicoptère

A partir de l'analyse des fichiers fournis (`fn_heliManager.sqf`, `fn_heliDispatch.sqf`, `fn_addHelicopterActions.sqf`, `PROMPT.md` et `INFO.md`), voici le document d'architecture pour le nouveau système.

## 1. Objectifs Principaux
1. **Unicité Absolue** : Un seul hélicoptère allié actif sur la carte à tout moment, géré de manière centralisée. Cet hélicoptère sera l'UH-60L (`CUP_I_UH60L_FFV_RACS`).
2. **Immersion et Suppression Dynamique** : Aucune disparition ou suppression visuelle sous les yeux des joueurs. L'hélicoptère ne sera supprimé (despawn) *que* s'il se trouve à plus de **1200 mètres** de tous les joueurs humains sur le serveur. 
3. **Comportement IA (RTB)** : Lors du RTB (Return To Base) ou de la fin d'une tâche, l'hélicoptère doit activement chercher à s'éloigner. S'il n'y a pas d'héliport à plus de 1200m, il se dirigera vers une coordonnée lointaine ou le bord de carte jusqu'à atteindre la distance requise avant de disparaître.
4. **Ciblage par Carte avec Ellipse** : Refonte de `fn_addHelicopterActions.sqf`. Au lieu de cibler la position `getPos player`, l'appel ouvrira la carte (via `onMapSingleClick`) comme pour le drone, permettant au joueur de cliquer pour définir la zone de largage/CAS. Une ellipse (ou un marqueur spécifique) sera dessinée sur la carte pendant la durée de la mission.
5. **Conservation des Fondations** : Maintien des logiques de descente, des altitudes de vol (déjà optimisées), et utilisation des points de spawn indiqués dans `INFO.md` (`Heliport_00` à `Heliport_XX`).

## 2. Analyse du Code Actuel et Modifications Prévues

### A. Le Dispatcher (`fn_heliDispatch.sqf`)
- Le dispatcher gère déjà un système de file d'attente avec priorités. Si l'hélicoptère unique est en train de s'éloigner (état `RTB` ou `IDLE` sans être détruit), une nouvelle requête de priorité égale ou supérieure l'interceptera en vol, lui évitant d'être supprimé et lui donnant un nouveau waypoint (réutilisation dynamique).

### B. Le Manager (`fn_heliManager.sqf`)
- **Type d'appareil** : Remplacement de la ligne `createVehicle ["CUP_I_CH47F_RACS", ...]` par `createVehicle ["CUP_I_UH60L_FFV_RACS", ...]`.
- **Condition de suppression dans `_fnRTB`** : 
  - Actuellement, l'hélicoptère est supprimé une fois arrivé à son point de retour ou après un délai de 180s. 
  - **Nouveau comportement** : L'hélicoptère vole vers un héliport. Une fois arrivé (ou sur le chemin), une boucle vérifie continuellement la distance de *tous* les joueurs (`allPlayers`). S'il y a un joueur à moins de 1200m, l'hélicoptère reçoit l'ordre de s'éloigner (vecteur de fuite) jusqu'à ce que la distance dépasse 1200m. Ce n'est qu'à ce moment-là que l'équipage et l'appareil sont `deleteVehicle`.

### C. Interface Utilisateur (`fn_addHelicopterActions.sqf`)
- Les actions directes `["LIVRAISON", getPos player, ...]` seront modifiées pour ouvrir la carte de la même manière que `fn_addDroneAction.sqf`.
- Une fois le clic effectué sur la carte, un marqueur de zone (`createMarkerLocal` ou global selon le besoin) type "Ellipse" sera généré et supprimé lorsque l'hélicoptère aura terminé l'action.

## 3. Questions de Design et Clarifications Requises

Afin de finaliser l'implémentation et de garantir qu'elle répond exactement à vos attentes, merci de clarifier ces points :

1. **L'Ellipse sur la Carte** : 
   - Souhaitez-vous une *ellipse* de zone pour tous les types d'actions (Livraison, Véhicule, Débarquement, Extraction), ou seulement pour le CAS (Appui aérien) qui couvre une zone large, avec plutôt un marqueur type "Icône" pour les livraisons précises ?
   
2. **Gestion du Point de Fuite (RTB)** :
   - Si les joueurs sont dispersés partout sur la carte (Zargabad est assez petite), il se peut que l'hélicoptère n'arrive jamais à s'éloigner à 1200m. Dans ce cas extrême, doit-il loiter (tourner en rond) en bordure de carte indéfiniment jusqu'à ce que les joueurs s'éloignent, ou doit-il atterrir sur un héliport et couper ses moteurs (rester persistant) ?

3. **Réactivité de l'Hélicoptère ("Un seul hélico")** :
   - Priorité aux taches en cours sur les demandes joueurs. Le joueur demande un CAS mais il faut exflitré un ottage ? Priorité a la tache donc l'ottage ! annulation de la mission

4. **Armement de l'UH-60L** :
   - L'UH-60L possède des miniguns latéraux (doorgunners). Souhaitez-vous qu'ils engagent activement les cibles ennemies pendant les phases de descente et de largage (comportement `COMBAT`), ou doivent-ils ignorer les tirs pour garantir la livraison (comportement `CARELESS`) ? Actuellement, le script les force en `CARELESS` pour le pilote et `RED` (tir à volonté) pour les canonniers. Maintenons-nous cela ?

---
*Ce fichier servira de cahier des charges. Une fois ces réponses obtenues, l'intégration du code pourra débuter.*
