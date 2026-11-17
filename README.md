# pm-chimie

Palais mental 3D pour retenir les 118 éléments chimiques dans l'ordre, par la méthode des loci.

**Jouer :** https://hugo-morana.github.io/pm-chimie/

## Organisation

- **Laboratoire moderne** : emplacements 0 à 99 (0 = neutron, 1 = hydrogène… 99 = einsteinium).
- **Laboratoire d'alchimiste** : emplacements 100 à 199 (100 = fermium… 118 = oganesson ; 119-199 libres).
- Chaque pièce a 10 panneaux, un par dizaine, sur 10 surfaces : mur gauche (0x), diagonale gauche (1x), mur du fond (2x), diagonale droite (3x), mur droit (4x), sol droit (5x), sol centre (6x), sol gauche (7x), plafond gauche (8x), plafond droit (9x). Couleurs des cadres selon le code MemoHugoDate (0 blanc, 1 rouge, 2 orange, 3 jaune, 4 vert, 5 bleu, 6 violet, 7 marron, 8 rose, 9 gris).
- Dans un panneau : x0 détaché au-dessus, puis la grille en serpentin x1 x2 x3 / x6 x5 x4 / x7 x8 x9.
- Chaque image agit sur la suivante (chaîne de liens), affichée dans la fiche et pendant la visite guidée.

## Fonctions

Visite guidée (‹ › élément, « » dizaine, zoom en 3 temps), visite libre (joystick / ZQSD, double-toucher pour avancer), plan, affichage de la chaîne, et tests à répétition espacée : apprentissage progressif, révision du jour, numéro → image, image → numéro, suite, chaîne.

Sur GitHub Pages, la progression est gardée dans le navigateur. Dans l'artifact claude.ai, elle est aussi enregistrée dans le compte.

## Version iPhone / iPad (SwiftUI)

Le dossier `swiftui/PMChimie.swiftpm` contient une version native de l'app (SwiftUI + SceneKit, iOS 17). Ouvre-le dans Xcode sur Mac ou dans Swift Playgrounds sur iPad. Détails dans `swiftui/PMChimie.swiftpm/README.md`.

## Fichiers

| Chemin | Rôle |
|---|---|
| `index.html` | Page autonome (GitHub Pages) |
| `artifact.html` | Même contenu, publié comme artifact claude.ai |
| `i/NNN.webp` | Image de l'élément NNN (640 px) |
| `t/NNN.webp` | Vignette de l'élément NNN (256 px, texture 3D) |
| `src/data.py` | Liste des éléments : image, décryptage, lien vers le suivant |
| `src/template.html` | Gabarit Three.js (r128) avec le marqueur `__DATA__` |
| `src/build.py` | Régénère `index.html` et `artifact.html` |

## Modifier une image ou un lien

1. Remplacer `i/NNN.webp` et `t/NNN.webp`, ou éditer la ligne `NNN|…` dans `src/data.py`.
2. `python3 src/data.py && python3 src/build.py`
