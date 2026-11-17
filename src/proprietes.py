"""Génère swiftui/PMChimie.swiftpm/Resources/proprietes.json (données chiffrées des 118 éléments).

Source : paquet Python `mendeleev` (pip install mendeleev). Les textes rédigés (description,
usages, étymologie…) sont dans src/fiches_fr.json et fusionnés ici.

    python3 src/proprietes.py
"""
import json, math, os, re, warnings
warnings.filterwarnings("ignore")
from mendeleev.fetch import fetch_table

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "swiftui", "PMChimie.swiftpm", "Resources", "proprietes.json")
TEXTES = os.path.join(ROOT, "src", "fiches_fr.json")

EV_KJ = 96.4853  # 1 eV par atome = 96,485 kJ/mol

FAMILLES = {1: "Non-métaux", 2: "Gaz nobles", 3: "Métaux alcalins", 4: "Métaux alcalino-terreux",
            5: "Métalloïdes", 6: "Halogènes", 7: "Métaux pauvres", 8: "Métaux de transition",
            9: "Lanthanides", 10: "Actinides"}
STRUCT = {"HEX": "hexagonal", "BCC": "cubique centré", "FCC": "cubique à faces centrées",
          "TET": "tétragonal", "DIA": "diamant", "CUB": "cubique", "SC": "cubique simple",
          "MCL": "monoclinique", "ORC": "orthorhombique", "RHL": "rhomboédrique"}
PAYS = {"Algeria": "Algérie", "Austrailia": "Australie", "Australia": "Australie", "Belarus": "Biélorussie",
        "Belgium": "Belgique", "Bolivia": "Bolivie", "Brazil": "Brésil", "CIS Countries (inc. Russia)": "CEI (dont Russie)",
        "Canada": "Canada", "Chile": "Chili", "China": "Chine", "Cuba": "Cuba", "DRC": "RD Congo",
        "Germany": "Allemagne", "Germany (likely)": "Allemagne", "Guinea": "Guinée", "India": "Inde",
        "Indonesia": "Indonésie", "Israel": "Israël", "Japan": "Japon", "Kazakhstan": "Kazakhstan",
        "Kyrgzstan": "Kirghizistan", "Malaysia": "Malaisie", "Mexico": "Mexique", "Mongolia": "Mongolie",
        "Morocco": "Maroc", "Mozambique": "Mozambique", "New Caledonia": "Nouvelle-Calédonie",
        "North Korea": "Corée du Nord", "Peru": "Pérou", "Philippines": "Philippines", "Poland": "Pologne",
        "Poland: Chile": "Chili", "Qatar": "Qatar", "Republic of Korea": "Corée du Sud", "Russia": "Russie",
        "Rwanda": "Rwanda", "South Africa": "Afrique du Sud", "Spain": "Espagne", "Tajikistan": "Tadjikistan",
        "Turkey": "Turquie", "USA": "États-Unis", "Ukraine": "Ukraine", "Unknown (likely USA)": "États-Unis",
        "Zambia": "Zambie", "Zimbabwe": "Zimbabwe"}
# durée en secondes pour chaque unité de demi-vie
SEC = {"ysec": 1e-24, "zsec": 1e-21, "asec": 1e-18, "psec": 1e-12, "nsec": 1e-9, "usec": 1e-6, "msec": 1e-3,
       "sec": 1, "minute": 60, "hour": 3600, "day": 86400}
AN = 365.25 * 86400
for u, k in {"year": 1, "kyear": 1e3, "Myear": 1e6, "Gyear": 1e9, "Tyear": 1e12, "Pyear": 1e15,
             "Eyear": 1e18, "Zyear": 1e21, "Yyear": 1e24}.items():
    SEC[u] = k * AN
MODES = {"A": "α", "B-": "β⁻", "B+": "β⁺", "EC": "CE", "e+": "β⁺", "SF": "FS", "IT": "TI", "2B-": "2β⁻",
         "2B+": "2β⁺", "EC+B+": "CE", "p": "p", "n": "n", "2p": "2p", "2n": "2n", "B-n": "β⁻n", "B+p": "β⁺p",
         "B+A": "β⁺α", "B-A": "β⁻α", "B-SF": "β⁻FS", "B+SF": "β⁺FS"}


def nb(x, nd=4):
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return None
    return float(f"{float(x):.{nd}g}")


def fr_num(x, nd=3):
    s = f"{x:.{nd}g}"
    if "e" in s:
        s = f"{x:,.0f}".replace(",", " ")
    return s.replace(".", ",")


SUP = str.maketrans("-0123456789", "⁻⁰¹²³⁴⁵⁶⁷⁸⁹")


def sci(x, unite):
    e = math.floor(math.log10(x))
    m = x / 10 ** e
    return f"{fr_num(m)}×10{str(e).translate(SUP)} {unite}"


def demi_vie(sec):
    if sec is None:
        return None
    if sec < 1e-9:
        return sci(sec, "s")
    if sec < 1e-6:
        return fr_num(sec * 1e9) + " ns"
    if sec < 1e-3:
        return fr_num(sec * 1e6) + " µs"
    if sec < 1:
        return fr_num(sec * 1e3) + " ms"
    if sec < 60:
        return fr_num(sec) + " s"
    if sec < 3600:
        return fr_num(sec / 60) + " min"
    if sec < 86400:
        return fr_num(sec / 3600) + " h"
    if sec < AN:
        return fr_num(sec / 86400) + " jours"
    a = sec / AN
    if a < 1e3:
        return fr_num(a) + " ans"
    if a < 1e6:
        return fr_num(a / 1e3) + " millier d'années" if a < 2e3 else fr_num(a / 1e3) + " milliers d'années"
    if a < 1e9:
        return fr_num(a / 1e6) + " millions d'années"
    if a < 1e12:
        return fr_num(a / 1e9) + " milliards d'années"
    return sci(a, "ans")


def origine(z):
    if z in (1, 2, 3):
        return "primordiale"
    if z in (4, 5):
        return "spallation"
    if z <= 26:
        return "stellaire"
    if z in (43, 61) or 84 <= z <= 89 or z == 91 or z in (93, 94):
        return "désintégration"
    if z > 94:
        return "synthétique"
    return "explosive"


def etat(fus, eb, z):
    if z in (6, 16, 34, 50, 87):  # allotropes ou valeurs manquantes : solides à 25 °C
        return "solide"
    if fus is None and eb is None:
        return "inconnu"
    if eb is not None and eb < 298.15:
        return "gaz"
    if fus is not None and fus > 298.15:
        return "solide"
    if fus is not None and eb is not None:
        return "liquide"
    return "inconnu"


def pays(v):
    if not isinstance(v, str):
        return []
    out = []
    for x in re.split(r"\s*\d\)\s*", v):
        x = x.strip()
        if x:
            p = PAYS.get(x, x)
            if p not in out:
                out.append(p)
    return out


def main():
    E = fetch_table("elements").set_index("atomic_number")
    I = fetch_table("isotopes")
    D = fetch_table("isotopedecaymodes")
    IE = fetch_table("ionizationenergies")
    OX = fetch_table("oxidationstates")
    modes = {}
    for _, r in D.iterrows():
        modes.setdefault(r.isotope_id, []).append(r["mode"])
    from mendeleev import element

    textes = json.load(open(TEXTES, encoding="utf-8")) if os.path.exists(TEXTES) else {}
    out = []
    for z in range(1, 119):
        r = E.loc[z]
        el = element(int(z))
        ion = IE[IE.atomic_number == z].sort_values("ion_charge")
        ei = [nb(v * EV_KJ) for v in ion.ionization_energy.tolist()[:8] if v == v]
        oxz = OX[OX.atomic_number == z]
        oxm = oxz[oxz.category == "main"] if "main" in set(oxz.category) else oxz
        ox = sorted(set(int(x) for x in oxm.oxidation_state.tolist()))
        try:
            couches = [int(v) for v in el.ec.electrons_per_shell().values()]
        except Exception:
            couches = []
        iso_rows = I[I.atomic_number == z]
        isos = []
        for _, s in iso_rows.iterrows():
            hl = None
            if s.is_radioactive and s.half_life == s.half_life and s.half_life_unit in SEC:
                hl = float(s.half_life) * SEC[s.half_life_unit]
            m = [MODES.get(x, x) for x in modes.get(s.id, [])]
            isos.append({"a": int(s.mass_number), "m": nb(s.mass, 7),
                         "ab": nb(s.abundance) if s.abundance == s.abundance else None,
                         "stable": not bool(s.is_radioactive), "s": hl, "mode": m})
        n_iso = len(isos)
        n_st = sum(1 for x in isos if x["stable"])
        n_bp = sum(1 for x in isos if any(k.startswith(("β⁺", "CE", "p")) for k in x["mode"]))
        n_bm = sum(1 for x in isos if any(k.startswith(("β⁻", "n")) for k in x["mode"]))
        n_a = sum(1 for x in isos if "α" in x["mode"])
        # isotopes principaux : naturels, stables ou à vie longue
        prin = [x for x in isos if x["stable"] or (x["ab"] or 0) > 0 or (x["s"] or 0) >= 3600]
        if len(prin) < 4:
            vivants = sorted([x for x in isos if (x["s"] or 0) >= 1], key=lambda x: -x["s"])
            for x in vivants:
                if x not in prin and len(prin) < 6:
                    prin.append(x)
        if len(prin) > 16:
            garde = [x for x in prin if x["stable"] or (x["ab"] or 0) > 0]
            reste = sorted([x for x in prin if x not in garde], key=lambda x: -(x["s"] or 0))
            prin = garde + reste[: max(0, 16 - len(garde))]
        prin.sort(key=lambda x: x["a"])
        for x in prin:
            x["demi"] = "stable" if x["stable"] else demi_vie(x["s"])
            if x["s"] is not None:
                x["s"] = nb(x["s"], 4)
        fus = nb(el.melting_point)
        eb = nb(el.boiling_point)
        if fus is None and eb is None and el.phase_transitions:
            pt = el.phase_transitions[0]
            fus, eb = nb(pt.melting_point), nb(pt.boiling_point)
        dy = r.discovery_year
        rec = {
            "n": z,
            "famille": FAMILLES.get(int(r.series_id)) if r.series_id == r.series_id else None,
            "bloc": r.block, "periode": int(r.period),
            "groupe": int(r.group_id) if r.group_id == r.group_id else None,
            "masse": nb(r.atomic_weight, 6),
            "etat": etat(fus, eb, z),
            "origine": origine(z),
            "config": r.electronic_configuration,
            "couches": couches,
            "enPauling": nb(r.en_pauling, 3), "enAllen": nb(r.en_allen, 4),
            "ae": nb(r.electron_affinity * EV_KJ) if r.electron_affinity == r.electron_affinity else None,
            "ei": ei, "oxy": ox,
            "rayonAt": nb(r.atomic_radius), "rayonCalc": nb(r.atomic_radius_rahm),
            "rayonCov": nb(r.covalent_radius_pyykko), "rayonVdw": nb(r.vdw_radius),
            "rayonMet": nb(r.metallic_radius),
            "densite": nb(r.density), "volMol": nb(el.atomic_volume) if el.atomic_volume else None,
            "fusion": fus, "ebullition": eb,
            "hFusion": nb(r.fusion_heat), "hVap": nb(r.evaporation_heat),
            "capa": nb(r.specific_heat_capacity, 3), "cond": nb(r.thermal_conductivity),
            "structure": STRUCT.get(r.lattice_structure) if isinstance(r.lattice_structure, str) else None,
            "annee": int(dy) if dy == dy else None,
            "decouvreursEn": r.discoverers if isinstance(r.discoverers, str) else None,
            "croute": nb(r.abundance_crust), "mer": nb(r.abundance_sea),
            "radioactif": n_st == 0,
            "prix": nb(r.price_per_kg, 3),
            "recyclage": r.recycling_rate if isinstance(r.recycling_rate, str) else None,
            "risque": nb(r.relative_supply_risk, 2),
            "concentration": nb(r.production_concentration, 3),
            "producteurs": pays(r.top_3_producers), "reserves": pays(r.top_3_reserve_holders),
            "nIso": n_iso, "nStables": n_st, "nBplus": n_bp, "nBmoins": n_bm, "nAlpha": n_a,
            "isotopes": [{k: x[k] for k in ("a", "m", "ab", "demi", "mode", "s")} for x in prin],
        }
        t = textes.get(str(z))
        if t:
            rec["texte"] = t
        out.append({k: v for k, v in rec.items() if v is not None and v != []})
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print(OUT, os.path.getsize(OUT), "octets,", sum(1 for x in out if "texte" in x), "fiches rédigées")


if __name__ == "__main__":
    main()
