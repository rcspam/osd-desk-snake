# OSD Desk Snake : design

Date : 2026-09-26. Cible : Plasma 6.6, Wayland, usage perso.

## But

Un OSD qui s'affiche au changement de bureau virtuel, dans le style de Kara
(pilules, numéros/noms, icônes, fenêtres ouvertes), configurable comme Kara,
avec en plus la position à l'écran. Il remplace l'OSD natif de KWin
(`desktopchangeosd`, désactivé chez l'utilisateur).

## Choix techniques

- Script KWin déclaratif (QML pur, sans compilation), id `osd-desk-snake`.
  Même mécanisme que l'OSD natif : `Connections { target: Workspace }` sur
  `currentDesktopChanged(previous)` (signature 6.6 : un seul argument).
  Fenêtres via la propriété `Workspace.windows` (pas de `windowList()` en QML).
- Fenêtre : `Window` QtQuick transparente, `transientParent: null` (sinon
  elle attend la fenêtre de son `Item` parent, qui n'existe pas dans un script
  KWin), propriété `outputOnly: true` lue par `InternalWindow::hitTest` pour
  laisser passer les clics. Les fenêtres internes de KWin vont dans
  `OverlayLayer`, au-dessus de tout.
- Le fond Plasma est dessiné dans le QML (`KSvg.FrameSvgItem`,
  `dialogs/background` ou `solid/dialogs/background`), sans flou.
  `PlasmaCore.Dialog` a été écarté : dans KWin il pose un masque de fenêtre et
  l'opacité de fenêtre produit un avertissement à chaque image du fondu.
- Fondu via l'opacité de l'`Indicator`.
- Config : `contents/config/main.xml` + `contents/ui/config.ui` (formulaire
  chargé par `kcm_kwin4_genericscripted`, groupe `[Script-osd-desk-snake]` de
  kwinrc). Couleurs via `KColorButton` (paquet `libkf6widgetsaddons-dev`).
- Rechargement de la config : le KCM des scripts ne prévient pas KWin
  (`ScriptingConfig::reload()` est un TODO). Le script appelle lui-même
  `org.kde.kwin.Scripting.start` par D-Bus 0,7 s après un changement (au plus
  toutes les 3 s, après l'animation de glissement des bureaux). Cet appel relit kwinrc sans recharger les scripts déjà lancés, puis
  l'OSD relit ses réglages et se met à jour s'il est encore visible.

## Comportement

- Affiche tous les bureaux, grille selon les rangées KWin (option : forcer
  une ligne ou une colonne). Le bureau courant est en surbrillance.
- Animation : l'OSD s'ouvre sur l'ancien bureau puis passe au nouveau
  (transition de taille, couleur, opacité).
- Écran actif uniquement. Rien si l'Overview est ouvert, rien s'il n'y a
  qu'un bureau (option).
- Délai avant affichage optionnel (les changements pendant ce délai se
  regroupent), fondu d'entrée, temps d'affichage, fondu de sortie, effet
  d'apparition (fondu, ou fondu et zoom), durée et courbe de l'animation de
  surbrillance : tout est réglable.
- Geste du pavé tactile (3 ou 4 doigts) ou de l'écran tactile : l'OSD
  apparaît dès le début du glissement, via des `SwipeGestureHandler` calqués
  sur les gestes de KWin (tous les gestes correspondants tournent en
  parallèle, celui de KWin n'est pas bloqué).

## Position

- Mode ancre : 9 points, marge vers l'intérieur, décalage X/Y en px.
- Mode libre : centre de l'OSD en % de la zone, borné à l'écran.
- Zone : écran moins les panneaux (option), sinon écran entier.

## Styles

- Pilules : forme pilule, cercle, carré, losange ou barre, l'active plus
  large ou plus grande (tailles réglables).
- Libellés : numéro, nom du bureau, modèle (`%d` numéro, `%n` nom) ou liste
  perso séparée par des virgules.
- Icônes : liste de noms d'icônes, icône de repli au-delà.
- Tâches : icônes des fenêtres du bureau (max réglable, `+n` au-delà),
  numéro estompé si le bureau est vide.
- Surbrillances pour libellés, icônes, tâches : plein, carré, ligne,
  plein + ligne. Cases arrondies, rondes ou carrées.
- Marque « bureau occupé » optionnelle pour tous les styles.
- Couleurs du thème Plasma ou perso. Fond : Plasma, Plasma opaque,
  transparent, couleur perso avec arrondi. Opacité du fond réglable.

## Découpage

- `logic.js` : fonctions pures (placement, grille, libellés, couleurs,
  occupation). Testées avec `qmltestrunner`.
- `Indicator.qml` et `styles/` : rendu seul, sans `org.kde.kwin`, pour
  pouvoir générer des aperçus PNG hors KWin (`tests/preview.qml`).
- `Settings.qml` : lecture de la config. `Osd.qml` : fenêtre, placement,
  minuteries. `main.qml` : branchement sur `Workspace`.
