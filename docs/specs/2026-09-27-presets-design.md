# OSD Desk Snake : presets

Date : 2026-09-27. Concerne l'app de réglages (`settings-app/`) et le lien en
haut de la page du script dans la Configuration du système.

## But

Enregistrer la configuration du moment sous un nom, la réappliquer plus tard en
un clic, et l'échanger avec d'autres sous forme de fichier.

## Décisions

- Un preset contient tous les réglages, position comprise.
- Les paquets livrent une série de presets (`presets/` du dépôt, installés dans
  `/usr/share/osd-desk-snake/presets`). L'app copie chacun une seule fois dans le
  dossier de l'utilisateur, où il se modifie comme les autres : un preset livré
  supprimé ne revient pas, et un preset de même nom n'est jamais écrasé.
- Import et export par fichier, avec un sélecteur de fichier.
- Un onglet Presets dans l'app de réglages.
- La page de la Configuration du système ne peut pas enregistrer de preset
  (formulaire généré par KWin à partir de `config.ui`, sans code possible). Elle
  reçoit un lien qui ouvre l'app sur l'onglet Presets.

## Fichier de preset

Un fichier par preset, au format INI de KConfig :

```
~/.config/osdsnake/presets/<nom>.osdsnake
```

```ini
[Preset]
Name=Nuit violette
Version=1

[Settings]
ActiveColor=160,0,200
Style=1
```

- `[Settings]` a les mêmes clés que le groupe `[Script-osd-desk-snake]` de
  kwinrc. Il est lu et écrit avec `KConfigLoader` et le schéma `main.xml` du
  script, déjà embarqué dans l'app. La conversion des types et l'oubli des clés
  inconnues viennent de là : une valeur illisible prend son défaut. Le schéma n'a
  pas de bornes min/max, donc une valeur hors plage passe telle quelle, comme
  dans un kwinrc édité à la main.
- Tous les réglages sont écrits, valeurs par défaut comprises (au contraire de
  kwinrc) : un preset garde son aspect quand une version future change un
  défaut. Une clé absente (fichier écrit à la main, ou réglage ajouté depuis)
  prend le défaut en vigueur.
- `Name` est le nom affiché. `Version` est la version du format (1), pour
  pouvoir le faire évoluer.
- Le nom du fichier vient du nom du preset : `/` remplacé par `-`, espaces et
  points en tête retirés. Deux presets ne peuvent pas porter le même nom, sans
  tenir compte de la casse.
- Le dossier est `QStandardPaths::GenericConfigLocation` + `/osdsnake/presets`,
  créé au lancement de l'app. Il est surveillé : un fichier `.osdsnake` copié
  dedans à la main apparaît aussitôt dans la liste.

## Appliquer un preset

Appliquer remplace tous les réglages : chaque clé prend la valeur du preset, ou
son défaut si le preset ne la contient pas. Le tout part en une seule sauvegarde
de kwinrc, donc un seul rechargement par KWin, et l'indicateur montre le
résultat tout de suite.

Le bouton Revert existant revient aux réglages de l'ouverture de la fenêtre :
il annule donc aussi un preset appliqué, sans code en plus.

Le preset « courant » est celui dont les valeurs, défauts compris, sont égales
aux réglages actuels. Il est surligné dans la liste. Dès qu'on modifie un
réglage, plus aucun preset n'est surligné.

Le dernier preset appliqué ou enregistré reste connu (config de l'app, groupe
`[Presets]`, clé `Loaded`), même après un redémarrage. Si les réglages ont
changé depuis, il apparaît en italique avec « (modifié) ». Il suit les
renommages et disparaît quand il est supprimé.

## Code C++

`SettingsStore` gagne deux méthodes :

- `QVariantMap values() const` : toutes les valeurs actuelles, clé par clé.
- `replaceAll(const QVariantMap &values)` : chaque clé prend la valeur donnée,
  ou son défaut si elle manque, puis une seule sauvegarde.

Nouvelle classe `PresetLibrary` (QObject exposé à QML), construite avec le
`SettingsStore`, le chemin du schéma et le dossier des presets (paramètre pour
les tests) :

- propriétés `names` (liste triée sans tenir compte de la casse) et
  `currentName` (vide si aucun ne correspond) ;
- `save(name)` : écrit les réglages actuels, écrase un preset du même nom ;
- `apply(name)` ;
- `rename(oldName, newName)` ;
- `remove(name)` ;
- `exportTo(name, url)` : copie le fichier, ajoute `.osdsnake` s'il manque ;
- `inspect(url)` : lit un fichier à importer sans rien copier, renvoie
  `{ name, error }` ;
- `importFrom(url)` : copie le preset dans le dossier, écrase un preset du même
  nom ;
- `contains(name)` : pour demander confirmation avant d'écraser.

À l'import, l'onglet appelle `inspect`, demande confirmation si `contains(name)`,
puis appelle `importFrom`.

Les actions qui échouent renvoient un message d'erreur traduit (vide si tout va
bien), que l'onglet affiche. `names` et `currentName` émettent leur signal de
changement après chaque action, et `currentName` aussi après chaque
modification d'un réglage.

## Onglet Presets

Ajouté après Colors, en dehors des onglets générés par `gen_config_ui.py`.

- En haut : « Save current as… » et « Import… ».
- Dessous : la liste des presets. Un clic applique le preset. Chaque ligne a
  trois boutons icônes : exporter, renommer, supprimer.
- Le nom est demandé dans une petite boîte de dialogue (enregistrer, renommer).
  Un nom vide est refusé. Un nom déjà pris demande confirmation avant d'écraser.
- Supprimer demande confirmation.
- Export et import passent par le `FileDialog` de Qt Quick, filtre
  « OSD Desk Snake preset (*.osdsnake) ».
- À l'import, un nom déjà pris demande la même confirmation qu'à
  l'enregistrement.
- Liste vide : un message qui explique comment créer le premier preset.
- Erreur (fichier illisible, sans groupe `[Preset]`, écriture impossible) : un
  message dans l'onglet, rien n'est modifié.

## Lien depuis la Configuration du système

- Le lien en haut de `config.ui` (généré par `tools/gen_config_ui.py`) gagne un
  second lien, `osd-desk-snake://presets`, à côté de `osd-desk-snake://settings`.
- `config.ui` gagne aussi un dernier onglet « Presets », sans champ : une courte
  explication, le lien `osd-desk-snake://presets` et le lien d'installation de
  l'app. Il rend la fonction visible depuis la Configuration du système.
- L'app lit l'URL reçue en argument. `presets` ouvre la fenêtre sur l'onglet
  Presets ; toute autre URL garde le comportement actuel.
- Si l'app tourne déjà, le second lancement transmet la page demandée à
  l'instance ouverte par D-Bus, qui bascule sur l'onglet et prend le focus.
- La page de la Configuration du système se ferme déjà quand l'app s'ouvre
  (script KWin, `main.qml`) : elle ne peut donc pas afficher des valeurs
  périmées après un preset.
- `config.ui` change : le `.kwinscript` et les paquets changent de version.

## Traductions et doc

- Nouvelles chaînes en anglais dans le code, traduites dans `po/fr.po`.
- README : une ligne sur les presets dans la section de l'app de réglages.

## Tests

Test unitaire Qt `presetlibrarytest`, sur un dossier temporaire et un kwinrc
temporaire :

- enregistrer puis appliquer redonne les mêmes valeurs ;
- un preset partiel remet les autres clés à leur défaut ;
- `currentName` suit l'application d'un preset et redevient vide après une
  modification ;
- renommer, supprimer, et le refus d'un nom vide ;
- exporter puis importer redonne le même preset ;
- import d'un fichier sans `[Preset]` ou illisible : erreur, rien ajouté ;
- valeur illisible dans un fichier importé : remplacée par son défaut.

À la main : l'onglet (création, application en direct, dialogues, liste vide,
erreurs), et le lien depuis la Configuration du système, app fermée puis app
ouverte.

## Hors périmètre

- Enregistrement depuis la page de la Configuration du système.
- Distribution de presets par le KDE Store (« Obtenir de nouveaux… »).
