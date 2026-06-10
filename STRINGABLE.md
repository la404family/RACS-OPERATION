## 🛠️ Méthode d'Intégration Non Destructive

les textes de la mission sont compilés par un script Python, il ne faut **pas** modifier manuellement `stringtable.xml` sous peine de voir les modifications écrasées lors de la prochaine génération.

La méthode propre consiste à ajouter les définitions dans l'un des fichiers XML sources de chaque fichier (par exemple `fn_addDroneAction.sqf`= `fn_addDroneAction.xml`), puis à régénérer la stringtable globale.

Voici la procédure pas à pas :

1. Créez un fichier XML à côté de votre script SQF (ex: `fn_addDroneAction.xml`).
2. Ajoutez vos clés de traduction avec le format suivant :
```xml
<?xml version="1.0" encoding="utf-8"?>
<Keys>
    <Key ID="STR_Drone_Surveillance">
        <Original>[DRONE] Surveillance</Original>
        <English>[DRONE] Surveillance</English>
        <French>[DRONE] Surveillance</French>
    </Key>
</Keys>
```
3. Dans votre fichier SQF, utilisez `localize "STR_Drone_Surveillance"`.
4. Exécutez le script `compile_stringtable.py` pour générer `stringtable.xml`.
