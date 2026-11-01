import json
SYM = "n H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U Np Pu Am Cm Bk Cf Es Fm Md No Lr Rf Db Sg Bh Hs Mt Ds Rg Cn Nh Fl Mc Lv Ts Og".split()

# n | nom | image | décryptage | lien vers n+1
ROWS = """0|Neutron|Neutron lumineux|Particule sans charge, « élément zéro » (neutronium, Z = 0)|Le neutron percute le dirigeable, qui s'élève en tanguant.
1|Hydrogène|Dirigeable|Le Hindenburg était gonflé à l'hydrogène|Le dirigeable prend feu, et sa chaleur gonfle d'un coup la montgolfière arc-en-ciel.
2|Hélium|Montgolfière arc-en-ciel|Ballon gonflé à l'hélium|La montgolfière lâche une pile géante, qui s'écrase au sol en crépitant.
3|Lithium|Pile|Pile au lithium|La pile envoie une décharge qui hérisse les cheveux blonds de Berylia.
4|Béryllium|Berylia, copine blonde|« Berylia » ≈ Béryllium|Berylia, cheveux dressés, grimpe en courant l'échelle du plongeoir.
5|Bore|Plongeoir|« Au bord » du bassin|Le plongeoir s'effondre sur le tas de charbon, qui explose en poussière noire.
6|Carbone|Blocs de charbon|Le charbon est du carbone|Le charbon brûlant tombe sur la bouteille d'azote, qui crache un nuage glacé et l'éteint.
7|Azote|Bouteille d'azote liquide qui fume|Azote liquide|Le nuage glacé gèle les bouteilles d'oxygène rouges, qui se mettent à rouler.
8|Oxygène|Bouteilles d'oxygène rouges|Bouteilles d'oxygène|Une bouteille d'oxygène roule sur le tube de dentifrice, et la pâte gicle.
9|Fluor|Tube de dentifrice|Dentifrice fluoré|Le jet de dentifrice traverse jusqu'au panneau rouge et éclabousse les néons violets, qui grésillent.
10|Néon|Tubes néon violets|Tubes néon|Un néon éclate et fend la salière, qui se met à tourner sur elle-même.
11|Sodium|Salière|Sel = chlorure de sodium|La salière déverse son sel sur les comprimés, qui moussent dans leurs plaquettes.
12|Magnésium|Plaquettes de comprimés|Comprimés de magnésium|Les plaquettes de comprimés s'enroulent dans le papier alu.
13|Aluminium|Rouleau de papier alu|Papier aluminium|Le rouleau d'alu se déroule à toute vitesse et renverse le sablier.
14|Silicium|Sablier|Le sable est de la silice|Le sablier se brise, et son sable se change en cailloux verts phosphorescents.
15|Phosphore|Cailloux verts phosphorescents|Phosphorescent|La lueur verte des cailloux enflamme l'allumette.
16|Soufre|Allumette|Tête d'allumette au soufre|L'allumette en feu tombe dans la piscine et déclenche un tsunami.
17|Chlore|Piscine en tempête|Eau chlorée|La vague de la piscine emporte le sous-marin, qui tangue.
18|Argon|Sous-marin|« Argonaute »|Le sous-marin tire une torpille en forme de banane.
19|Potassium|Banane|Banane riche en potassium|La banane plonge dans la bouteille de lait et fait un milkshake, qui s'envole vers le mur du fond.
20|Calcium|Bouteille de lait|Le lait apporte du calcium|Le milkshake de la bouteille de lait éclabousse le Viking jusque dans la barbe.
21|Scandium|Viking|Scandinavie|Le Viking, furieux, donne un coup de corne dans le globe d'Atlas, qui vacille.
22|Titane|Atlas portant le monde|Atlas est un titan|Atlas lâche le globe sur le toit du van, et les chats jaillissent par les fenêtres.
23|Vanadium|Van rempli de chats|« Van-a-dium »|Le van freine si fort que sa jante chromée se détache et file en roulant.
24|Chrome|Jante chromée|Jante chromée|La jante percute la pile de mangas, et les tomes volent partout.
25|Manganèse|Pile de mangas|« Manga-nèse »|Les mangas s'empilent sous le fer à repasser rouillé, qui les aplatit en fumant.
26|Fer|Fer à repasser rouillé|Fer|Le fer brûlant touche la queue du cobra, qui se dresse en sifflant.
27|Cobalt|Cobra|« Co-balt »|Le cobra mord la basket Nike et s'enroule autour d'elle.
28|Nickel|Basket Nike|« Ni-kel »|La basket Nike shoote dans les tuyaux en cuivre, qui s'entrechoquent comme des cloches.
29|Cuivre|Tuyaux en cuivre|Tuyauterie en cuivre|Les tuyaux crachent un jet d'eau qui traverse jusqu'au panneau jaune et inonde le comptoir en zinc.
30|Zinc|Comptoir de bar en zinc|Le « zinc » du bistrot|Le comptoir en zinc fait glisser une chope de bière qui renverse le coq.
31|Gallium|Coq|Le coq gaulois (Gaule)|Le coq chante et arrache le drapeau allemand avec son bec.
32|Germanium|Drapeau allemand|Germanie|Le drapeau allemand s'enroule autour des deux rappeurs d'Arsenik.
33|Arsenic|Deux rappeurs|Le groupe Arsenik|Les rappeurs tendent leur micro à Selena, qui se met à chanter.
34|Sélénium|Selena, jeune femme brune|« Selena » ≈ Sélénium|Selena attrape le broc et le renverse.
35|Brome|Broc d'eau|« Broc » ≈ Brome|L'eau du broc arrose les cristaux de kryptonite, qui s'illuminent en vert.
36|Krypton|Cristaux de kryptonite|Kryptonite|La kryptonite éclate et projette un rubis.
37|Rubidium|Rubis|« Rubi-dium »|Le rubis se plante dans le torse du tronc musclé.
38|Strontium|Tronc d'arbre musclé|« S-tronc-tium »|Le tronc musclé tord l'étrier à mains nues.
39|Yttrium|Étrier|« Y-trium » ≈ étrier|L'étrier, lancé comme un fer à cheval, vole jusqu'au mur droit et s'accroche au Z du chapiteau.
40|Zirconium|Z et chapiteau de cirque|« Z-circ-onium »|Le Z du chapiteau bascule, et Niobe l'esquive d'un saut au ralenti.
41|Niobium|Niobe (Matrix)|« Niobe » ≈ Niobium|Niobe atterrit sur le dos de la baleine, qui s'arrache de son socle.
42|Molybdène|Baleine (Moby Dick)|« Moby-bdène »|La baleine s'écrase sur les engrenages, qui se mettent à tourner en grinçant.
43|Technétium|Engrenages|Technique|Les engrenages happent la statuette en rut, qui grince en tournant avec eux.
44|Ruthénium|Statuette en rut|« Ruth-énium » ≈ en rut|La statuette en rut charge le Colosse de Rhodes, qui vacille dans la mer.
45|Rhodium|Colosse de Rhodes|Rhodes|Le Colosse enjambe la mer et écrase les dômes du palais.
46|Palladium|Palais|« Pala-dium »|Le palais déverse par ses fenêtres une pluie de couverts en argent.
47|Argent|Couverts en argent|Argenterie|La fourchette crochète le cadenas posé sur le savon.
48|Cadmium|Cadenas sur un savon|« Cad-mium »|Le cadenas se referme sur le turban du Sikh.
49|Indium|Sikh au turban|Inde|Le Sikh déroule son turban jusqu'au sol et appuie sur l'interrupteur, et tout s'éteint.
50|Étain|Interrupteur|« Éteint »|L'interrupteur lance une décharge qui retourne le moine la tête en bas.
51|Antimoine|Moine la tête en bas|« Anti-moine »|Le moine fait tourner la Terre sur ses pieds jusqu'à ce qu'elle fonde.
52|Tellure|La Terre qui fond|Tellus, la Terre|La Terre fondue coule sur le tas de gros sel.
53|Iode|Gros sel|Sel iodé|Le gros sel est projeté dans les yeux de Xena, qui dégaine son épée.
54|Xénon|Xena la guerrière|« Xena » ≈ Xénon|Xena tranche la couronne de laurier en deux.
55|Césium|Couronne de laurier|César|La couronne de laurier retombe sur la tête de Barry, qui se met à chanter.
56|Baryum|Barry, chanteur à lunettes noires|« Barry » ≈ Baryum|La voix grave de Barry fait vibrer la lanterne, qui s'allume.
57|Lanthane|Lanterne|« Lanterne » ≈ Lanthane|La lanterne brûlante fait éclater les cerises.
58|Cérium|Cerises|« Cerise » ≈ Cérium|Les cerises tombent dans le réchaud et flambent.
59|Praséodyme|Réchaud|« Brasero » ≈ Praséodyme|Le feu du réchaud court au sol jusqu'au panneau violet, et Neo l'esquive en se cambrant en arrière.
60|Néodyme|Neo (Matrix)|« Neo-dyme »|Neo, d'un coup de pied au ralenti, fait vaciller la torche de Prométhée.
61|Prométhium|Prométhée et sa torche|Prométhée, le feu volé aux dieux|Prométhée plonge sa torche dans l'aquarium, et le pirate en jaillit, furieux.
62|Samarium|Pirate dans un aquarium|« Sam-aquarium »|Le pirate plante son sabre dans le drapeau européen et l'arrache.
63|Europium|Drapeau européen|Europe|Le drapeau européen s'enroule autour des skis de Gad Elmaleh, qui chute.
64|Gadolinium|Gad Elmaleh à skis avec un bidon de gasoline|« Gad » + gasoline ; les skis = 64 (objet MemoHugoDate)|Gad Elmaleh vide son bidon de gasoline sur le sac de terre, qui s'imbibe et s'affaisse.
65|Terbium|Sac de terre|« Ter-bium »|Le sac de terre se déverse sur l'homme à lunettes, qui lève ses dix doigts pour se protéger.
66|Dysprosium|Homme montrant ses dix doigts|« Dix-prosium »|L'homme aux dix doigts arrache le chapeau et la loupe de Sherlock.
67|Holmium|Chapeau et loupe de Sherlock Holmes|Holmes|La loupe concentre le soleil et met le feu à l'herbe.
68|Erbium|Herbe|« Herbe-ium »|L'herbe pousse si vite qu'elle soulève les tuiles.
69|Thulium|Tuiles|« Tuile-ium »|Les tuiles glissent jusqu'au panneau marron et s'enfoncent dans la terre du Y.
70|Ytterbium|Un Y planté dans la terre|« Y-terre-bium »|La jeune pousse du Y s'enroule autour du manche du luth.
71|Lutécium|Luth|« Luth-écium »|Le luth joue une mélodie qui fait danser ALF.
72|Hafnium|ALF|« Haf » ≈ ALF|ALF attrape les tentacules et les gobe comme des spaghettis.
73|Tantale|Tentacules|« Tenta-cule » ≈ Tantale|Les tentacules saisissent l'ampoule, qui leur tire la langue.
74|Tungstène|Ampoule qui tire la langue|Tongue + filament en tungstène|L'ampoule s'allume et éblouit le renne.
75|Rhénium|Renne|« Renne-ium »|Le renne déterre un os avec ses bois.
76|Osmium|Os|« Os-mium »|L'os rebondit et frappe l'œil, qui s'injecte de sang.
77|Iridium|Œil|Iris|L'œil roule sur la platine et tourne avec le disque.
78|Platine|Platine vinyle|Platine|La platine tourne si vite qu'elle projette le lingot d'or.
79|Or|Lingot d'or|Or|Le lingot d'or s'envole jusqu'au plafond rose et brise le thermomètre, dont le mercure s'écoule.
80|Mercure|Thermomètre|Thermomètre à mercure|Le mercure du thermomètre coule dans les escarpins, qui glissent.
81|Thallium|Escarpins|« Talon » ≈ Thallium|Un talon aiguille perce la cartouche, qui explose en pluie de plombs.
82|Plomb|Cartouche de fusil|Plombs de chasse|Les plombs volent vers Julie, qui les arrête d'une main en souriant.
83|Bismuth|Julie Bismuth, une amie|Son nom de famille|Julie déploie le drapeau polonais.
84|Polonium|Drapeau polonais|Pologne|Le drapeau polonais claque et fait tomber l'as de pique.
85|Astate|As de pique|« As-tate »|L'as de pique, lancé comme un frisbee, tranche les cordes du radeau.
86|Radon|Radeau|« Radeau » ≈ Radon|Le radeau dérive et accroche le drapeau français, qu'il emporte.
87|Francium|Drapeau français|France|Le drapeau français, planté dans le potager, fait sortir un radis géant.
88|Radium|Radis|« Radis-um »|Le radis tombe dans le pot d'Activia et l'éclabousse.
89|Actinium|Yaourt Activia|« Activia » ≈ Actinium|Le yaourt jaillit jusqu'au plafond gris et éclabousse Thor.
90|Thorium|Thor|« Thor-ium »|Thor abat son marteau sur le pot au bouclier, qui résiste.
91|Protactinium|Pot de yaourt avec un bouclier|« Protège » + Actinium|Le bouclier renvoie l'éclair sur la centrale nucléaire, qui crache sa fumée.
92|Uranium|Centrale nucléaire|Combustible nucléaire|Le trident transperce la fumée de la centrale.
93|Neptunium|Trident de Neptune|Neptune|Le trident pique les fesses de Pluto, qui bondit en hurlant.
94|Plutonium|Pluto|« Pluto-nium »|Pluto mord le drapeau américain et le secoue.
95|Américium|Drapeau américain|Amérique|Le drapeau américain fouette le sachet de curry, qui explose en poudre.
96|Curium|Sachet de curry|« Curry-um »|Le curry atterrit sur la langue de l'ours : « Beurk ! »
97|Berkélium|Ours qui tire la langue|« Beurk »|L'ours recrache tout sur la Cadillac rose du rappeur.
98|Californium|Rappeur devant une Cadillac rose|Californie|La Cadillac rose recule et renverse le tableau d'Einstein.
99|Einsteinium|Einstein et son tableau|Einstein|Einstein lance sa craie, qui file par le couloir jusqu'au labo d'alchimiste et atterrit dans la cour de la ferme.
100|Fermium|Ferme|« Ferme-ium »|Les vaches de la ferme piétinent le tableau périodique et en éparpillent les cases.
101|Mendélévium|Tableau périodique|Mendeleïev, son auteur|Le tableau périodique se roule en ruban, au bout duquel pend la médaille Nobel.
102|Nobélium|Médaille Nobel|Alfred Nobel|La médaille Nobel roule dans le sable jusqu'aux pieds de Lawrence d'Arabie, qui la ramasse.
103|Lawrencium|Lawrence d'Arabie|Lawrence|Lawrence se rase avec le rasoir géant posé sur la Ford T, puis démarre.
104|Rutherfordium|Rasoir et Ford T|« Ru-ther-Ford »|La Ford T klaxonne, et Dumbo s'envole de peur en battant des oreilles.
105|Dubnium|Dumbo|« Dub-nium » ≈ Dumbo|Dumbo atterrit sur la tête du cyborg, qui le repousse d'un bras mécanique.
106|Seaborgium|Cyborg|« Sea-borg-ium »|Le cyborg arrache les orbites de l'atome où le gorille est enfermé.
107|Bohrium|Gorille dans un atome|L'atome de Bohr|Le gorille libéré attrape le grappin et s'y balance.
108|Hassium|Grappin|« Hass » ≈ crochet|Le grappin crochète la toque du petit cuisinier et l'arrache.
109|Meitnérium|Petit cuisinier à toque|« Maître » cuisinier|Le cuisinier lance sa spatule, qui file jusqu'au panneau suivant et atterrit au centre du stade.
110|Darmstadtium|Stade|« Darm-stadt »|La ola du stade fait jaillir le génie couronné.
111|Roentgenium|Génie couronné|« Roi-génie »|Le génie exauce un vœu et fait apparaître la Coupe du monde.
112|Copernicium|Coupe du monde|« Coupe-ernicium »|La Coupe du monde tombe et écrase l'oignon, qui fait pleurer tout le monde.
113|Nihonium|Oignon|« Ni-hon » ≈ oignon|L'odeur de l'oignon fait éternuer la truffe du chien.
114|Flérovium|Truffe de chien|Le flair|La truffe flaire une piste jusqu'à la cathédrale Saint-Basile et renifle ses bulbes.
115|Moscovium|Cathédrale Saint-Basile|Moscou|Les bulbes enneigés de la cathédrale s'effondrent sur la Mort, qui grelotte.
116|Livermorium|La Mort sous la neige|« L'hiver-mort »|La Mort, d'un coup de faux, tranche la raquette et la balle de tennis.
117|Tennessine|Raquette et balle de tennis|« Tennis-ine »|La moitié de balle frappe Wolverine en pleine tête, et il hurle en sortant ses griffes.
118|Oganesson|Wolverine qui hurle|« Logan-son »|"""
els = []
for line in ROWS.strip().split("\n"):
    n, nom, img, deco, lien = line.split("|")
    n = int(n)
    els.append(dict(n=n, s=SYM[n], nom=nom, img=img, deco=deco, lien=lien))
assert [e["n"] for e in els] == list(range(119))
import pathlib
json.dump(els, open(pathlib.Path(__file__).resolve().parent / "elements.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(els))
