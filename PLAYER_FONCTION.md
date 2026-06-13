# MANUEL OPÉRATIONNEL DU CHEF DE SECTION (RACS)

**NIVEAU D'ACCRÉDITATION :** CONFIDENTIEL DÉFENSE  
**DESTINATAIRE :** Chef d'Escouade (Leader)  
**SUJET :** Protocoles de commandement et ressources d'appui tactique disponibles sur le théâtre d'opérations.

Ce manuel détaille l'ensemble des commandes tactiques (via molette) à votre disposition sur le terrain. En tant que chef de section, vous avez autorité absolue sur vos hommes et un accès direct aux moyens de soutien du Haut Commandement.

---

## 1. COMMANDEMENT ET GESTION DE L'ESCOUADE

Vos hommes sont des professionnels, mais ils attendent vos ordres. Utilisez ces commandes pour maintenir la cohésion et l'efficacité de l'escouade.

### 1.1. Règles d'Engagement (RoE)
* **Interface :** Menu dynamique (Action molette).
* **Description :** Modifie instantanément le comportement tactique de l'ensemble de votre escouade.
* **Modes disponibles :**
  * **Infiltration :** Déplacement furtif, silencieux, armes baissées.
  * **Patrouille :** Déplacement standard, vitesse modérée, formation espacée.
  * **Vigilance :** Armes levées, conscience situationnelle accrue, prêts à faire feu.
  * **Assaut :** Vitesse maximale, comportement agressif pour prendre l'ascendant.
  * **Charge :** Mouvement désordonné et ultra-rapide vers l'objectif, ignorer les tirs de suppression.
  * **Défense :** Tenir la position, chercher un couvert, riposte immédiate.
  * **Reset :** Retour au comportement standard de l'IA.

### 1.2. Regroupement Forcé (Rally)
* **Interface :** Action blanche `Regroupement IA`.
* **Condition :** Avoir des fantassins sous vos ordres (hors véhicules).
* **Description :** Si l'escouade est dispersée ou si un soldat est bloqué sous le feu ennemi, cet ordre déclenche une réinitialisation agressive de leur comportement. Ils abandonneront leur couverture actuelle pour se reformer en colonne serrée derrière vous. Idéal pour "débloquer" une unité récalcitrante.

### 1.3. Procédure de Soin Automatique
* **Interface :** Action verte `Soin Automatique IA`.
* **Condition :** Au moins une IA blessée dans le groupe ET en possession d'une trousse de premiers secours (FirstAidKit).
* **Description :** Ordonne un arrêt de la progression pour traitement médical immédiat. L'IA blessée mettra un genou à terre, rangera son arme et s'appliquera les premiers soins avant de reprendre sa place en formation.
* **Refus (Négatif) :** Le QG ou l'escouade vous informera verbalement ("Negative! Nobody has a medkit.") si les réserves médicales sont épuisées.

### 1.4. Nettoyage de Secteur (CQB)
* **Interface :** Action jaune `Fouiller les bâtiments`.
* **Condition :** Présence de bâtiments à moins de 55 mètres.
* **Description :** Ordre d'assaut urbain. Vos hommes vont automatiquement se répartir et s'infiltrer dans les bâtiments environnants. L'IA priorisera toujours les points hauts (toits et étages) avant de sécuriser le rez-de-chaussée.
* **Protocole :** Déploiement agressif en quinconce. Une fois le point sécurisé, l'unité observe les environs pendant quelques secondes puis retourne automatiquement se placer en formation sur vous.

---

## 2. APPUI AÉRIEN ET LOGISTIQUE (HQ)

Le Haut Commandement a affecté **un unique hélicoptère UH-60L** au secteur opérationnel. Vous partagez cette ressource avec d'autres unités. Les missions sont traitées selon un protocole de priorité strict.

* **Interface :** Action blanche pour ouvrir le canal radio, puis clic sur la carte (`M`) pour désigner les coordonnées (LZ/DZ/Cible).

### 2.1. Les Missions Disponibles
* **Appui Aérien Rapproché (CAS) :** L'hélicoptère effectuera des passes de tir (miniguns) sur la zone désignée. *Attention : Cooldown imposé de 5 minutes entre chaque frappe.*
* **Livraison de Munitions :** Largage d'une caisse de ravitaillement par l'hélicoptère.
* **Livraison de Véhicule :** Héliportage d'un véhicule léger de transport. *Limité à une seule utilisation par déploiement.*
* **Débarquement (Renforts) :** L'hélicoptère larguera une escouade de renforts d'infanterie directement sur la zone.
* **Extraction :** L'hélicoptère se posera sur la LZ désignée pour évacuer l'escouade. C'est le seul moyen de terminer la mission et de rentrer à la base.

### 2.2. Réapprovisionnement sur Caisse (Resupply)
* **Interface :** Action dorée directement sur la caisse de munitions larguée.
* **Description :** Ordonne à vos hommes de se servir dans la caisse à tour de rôle. Le processus de rechargement est complet : chargeurs principaux, armes de poing, grenades, fumigènes et trousses de soins. La caisse reste exploitable tant qu'elle n'est pas détruite.

### 2.3. Gestion des Priorités et Refus (SQUELCH RADIO)
Si le réseau est saturé, vos requêtes peuvent être refusées ou interrompues.
* **Priorité Basse (Niveau 1) :** CAS, Livraisons, Renforts. L'hélico doit avoir terminé sa tâche précédente pour accepter ces ordres. Si l'oiseau est déjà en vol, vous recevrez un refus radio vous indiquant sa mission en cours.
* **Priorité Haute (Niveau 2) : L'Extraction.** Une demande d'extraction annulera IMMÉDIATEMENT toute mission de priorité basse en cours. L'hélico se réorientera vers votre LZ sans délai.
* **Priorité Absolue (Niveau 3) :** Tâches scénarisées (Commandement). Le QG peut détourner l'hélicoptère à tout moment pour une mission critique prioritaire, annulant tous vos ordres.

---

## 3. SURVEILLANCE ET RECONNAISSANCE AÉRIENNE

### 3.1. Déploiement Drone (MQ-9 Reaper)
* **Interface :** Action blanche `Demander un drone de surveillance`.
* **Description :** Demande la mise sur orbite d'un drone à 350m d'altitude au-dessus de coordonnées précises. Le drone balaiera le secteur (400m de rayon) pendant 5 minutes.
* **Flux de données (HUD/Carte) :** La position exacte des forces ennemies vivantes vous sera retransmise en temps réel directement sur votre équipement cartographique (Marqueurs rouges). Les cadavres ou unités quittant le secteur disparaîtront du radar.
* **Refus / Disponibilité :** Le drone doit faire le plein après son temps de vol (RTB). Vous devrez attendre 2 minutes (cooldown) après son départ avant de pouvoir le solliciter à nouveau.
