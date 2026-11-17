# PM Chimie — version SwiftUI

Application iPhone et iPad du palais mental des 118 éléments chimiques, reprise de la version web
(hugo-morana/pm-chimie). C'est un projet « app » au format Swift Playgrounds.

## Ouvrir et lancer

- **Sur Mac** : double-clic sur `PMChimie.swiftpm` (Xcode 15 ou plus), choisir un simulateur ou ton iPhone, puis ▶︎.
  Pour l'installer sur ton iPhone, choisis ton équipe dans *Signing & Capabilities*.
- **Sur iPad** : ouvrir le dossier dans Swift Playgrounds 4.4 ou plus, puis ▶︎.

iOS 17 minimum.

## Ce que fait l'app

- Les deux pièces en 3D (SceneKit) : laboratoire moderne (0–99) et laboratoire d'alchimiste (100–199),
  avec les mêmes 10 surfaces, panneaux colorés (code MemoHugoDate), grilles en serpentin et images.
- Visite guidée : ‹ › élément, « » dizaine, zoom en 3 temps (vue d'ensemble, panneau, emplacement),
  balayage gauche/droite sur la 3D, passage par le couloir entre les deux pièces.
- Fil animé et bandeau du lien quand on passe d'un élément au suivant ; affichage de toute la chaîne.
- Visite libre : joystick pour avancer, glisser pour regarder, toucher une image pour s'en approcher.
- Fiche : numéro, symbole, emplacement, image, décryptage, liens vers le suivant et depuis le précédent.
- Plan de toutes les dizaines.
- Tests à répétition espacée (boîtes 0 à 5, intervalles 0-1-2-4-8-16 jours) : apprentissage progressif,
  révision du jour, numéro → image, image → numéro, suite, chaîne. La progression est gardée sur l'appareil.

## Fichiers

| Fichier | Rôle |
|---|---|
| `Package.swift` | Description de l'app (nom, icône, orientations) |
| `ContentView.swift` | Point d'entrée, barres, superpositions sur la 3D, joystick |
| `Model.swift` | État de la visite et déroulé des tests |
| `SceneController.swift` | Construction de la scène, caméra, gestes, visite libre |
| `Palace.swift` | Géométrie des pièces, emplacements, cadrages |
| `Textures.swift` | Murs, sols, panneaux et enseignes dessinés par programme |
| `SRS.swift` | Répétition espacée et séances de test |
| `FicheView.swift` | Fiche de l'élément, agrandissement, plan |
| `TestViews.swift` | Menu des tests, questions, progression |
| `Data.swift` | Chargement des éléments et des images |
| `Resources/` | `elements.json`, images 640 px (`001.webp`…) et vignettes 256 px (`t001.webp`…) |

## Modifier une image ou un lien

Remplacer `Resources/NNN.webp` et `Resources/tNNN.webp`, ou régénérer `Resources/elements.json`
depuis `src/data.py` du dépôt web (`python3 src/data.py`, puis copier `src/elements.json`).
