import SwiftUI
import Charts

// MARK: - Données (Resources/proprietes.json, généré par src/proprietes.py)

struct Isotope: Decodable, Hashable {
    let a: Int
    let m: Double?
    let ab: Double?
    let demi: String?
    let mode: [String]?
    let s: Double?
    var stable: Bool { demi == "stable" }
}

struct UsagePart: Decodable, Hashable {
    let label: String
    let pct: Double
}

struct Pictogramme: Decodable, Hashable {
    let code: String
    let label: String
}

struct FicheTexte: Decodable {
    let description: String?
    let usages: String?
    let parts: [UsagePart]?
    let partsSource: String?
    let etymologie: String?
    let symbolique: String?
    let decouvreurs: String?
    let sgh: [Pictogramme]?
}

struct Props: Decodable, Identifiable {
    let n: Int
    let famille: String?
    let bloc: String?
    let periode: Int?
    let groupe: Int?
    let masse: Double?
    let etat: String?
    let origine: String?
    let config: String?
    let couches: [Int]?
    let enPauling: Double?
    let enAllen: Double?
    let ae: Double?
    let ei: [Double]?
    let oxy: [Int]?
    let rayonAt: Double?
    let rayonCalc: Double?
    let rayonCov: Double?
    let rayonVdw: Double?
    let rayonMet: Double?
    let densite: Double?
    let volMol: Double?
    let fusion: Double?
    let ebullition: Double?
    let hFusion: Double?
    let hVap: Double?
    let capa: Double?
    let cond: Double?
    let structure: String?
    let annee: Int?
    let decouvreursEn: String?
    let croute: Double?
    let mer: Double?
    let radioactif: Bool?
    let prix: Double?
    let recyclage: String?
    let risque: Double?
    let concentration: Double?
    let producteurs: [String]?
    let reserves: [String]?
    let nIso: Int?
    let nStables: Int?
    let nBplus: Int?
    let nBmoins: Int?
    let nAlpha: Int?
    let isotopes: [Isotope]?
    let texte: FicheTexte?
    var id: Int { n }
}

enum PropsStore {
    static let all: [Int: Props] = {
        guard let url = Bundle.module.url(forResource: "proprietes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Props].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: list.map { ($0.n, $0) })
    }()
    static func get(_ n: Int) -> Props? { all[n] }
}

// MARK: - Mise en forme

enum Fmt {
    static func num(_ x: Double?, _ digits: Int = 3) -> String {
        guard let x else { return "—" }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.maximumSignificantDigits = max(digits, abs(x) < 1e15 ? String(Int(abs(x))).count : digits)
        f.usesSignificantDigits = true
        return f.string(from: NSNumber(value: x)) ?? "\(x)"
    }
    static func unit(_ x: Double?, _ u: String, _ digits: Int = 3) -> String {
        x == nil ? "—" : num(x, digits) + " " + u
    }
    static func celsius(_ k: Double?) -> String {
        guard let k else { return "—" }
        return num(k, 4) + " K · " + num(k - 273.15, 4) + " °C"
    }
    static func ppm(_ x: Double?) -> String {
        guard let x else { return "—" }
        if x >= 1000 { return num(x / 10000, 3) + " %" }
        if x >= 0.001 { return num(x, 3) + " mg/kg" }
        return num(x * 1e6, 3) + " ng/kg"
    }
    static func siecle(_ annee: Int?) -> String {
        guard let a = annee else { return "Antiquité" }
        let s = a / 100 + 1
        let romains = [16: "XVI", 17: "XVII", 18: "XVIII", 19: "XIX", 20: "XX", 21: "XXI", 13: "XIII", 15: "XV"]
        return "\(romains[s] ?? "\(s)")e siècle"
    }
}

/// Couleur d'accent d'une famille d'éléments.
func familleColor(_ f: String?) -> Color {
    switch f {
    case "Métaux alcalins": return Color(hex: 0xff6b6b)
    case "Métaux alcalino-terreux": return Color(hex: 0xffa94d)
    case "Métaux de transition": return Color(hex: 0xf4c430)
    case "Métaux pauvres": return Color(hex: 0x8ce99a)
    case "Métalloïdes": return Color(hex: 0x38d9a9)
    case "Non-métaux": return Color(hex: 0x4dabf7)
    case "Halogènes": return Color(hex: 0x748ffc)
    case "Gaz nobles": return Color(hex: 0xb197fc)
    case "Lanthanides": return Color(hex: 0xf783ac)
    case "Actinides": return Color(hex: 0xe599f7)
    default: return Color(hex: 0xadb5bd)
    }
}

let chartPalette: [Color] = [Color(hex: 0xf783ac), Color(hex: 0x4dabf7), Color(hex: 0xffa94d),
                             Color(hex: 0x38d9a9), Color(hex: 0xb197fc), Color(hex: 0xffd43b),
                             Color(hex: 0xff6b6b), Color(hex: 0x8ce99a)]

// MARK: - Fiche détaillée

struct ElementDetailView: View {
    let n: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let E = PM.elements[n]
        NavigationStack {
            ScrollView {
                if let P = PropsStore.get(n) {
                    let accent = familleColor(P.famille)
                    VStack(alignment: .leading, spacing: 18) {
                        DetailHeader(E: E, P: P, accent: accent)
                        GlanceGrid(P: P, accent: accent)
                        if let t = P.texte { TextCards(t: t, accent: accent) }
                        AtomCard(P: P, symbol: E.s, accent: accent)
                        if let ei = P.ei, ei.count > 1 { IonisationCard(ei: ei, accent: accent) }
                        TrendCard(n: n, accent: accent)
                        PhysiqueCard(P: P)
                        ChimieCard(P: P, accent: accent)
                        IsotopesCard(P: P, symbol: E.s, accent: accent)
                        AbondanceCard(P: P, accent: accent)
                        HistoireCard(P: P, accent: accent)
                        if let sgh = P.texte?.sgh, !sgh.isEmpty { SGHCard(items: sgh) }
                        Text("Données : base mendeleev (Python). Textes reformulés.")
                            .font(.caption2).foregroundStyle(.secondary).padding(.top, 4)
                    }
                    .padding()
                } else {
                    Text("Pas de fiche pour cet emplacement.").foregroundStyle(.secondary).padding(40)
                }
            }
            .background(Color(hex: 0x15171a).ignoresSafeArea())
            .navigationTitle("\(E.nom)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
        }
    }
}

// MARK: - Carte générique

struct Card<Content: View>: View {
    let title: String
    var icon: String? = nil
    var accent: Color = .copper
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).foregroundStyle(accent) }
                Text(title).font(.headline)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBG, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(lineColor))
    }
}

struct ValueRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit()).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - En-tête

struct DetailHeader: View {
    let E: Element
    let P: Props
    let accent: Color
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("\(P.n)").font(.caption.bold().monospacedDigit())
                    Spacer()
                    Text(Fmt.num(P.masse, 6)).font(.caption2.monospacedDigit())
                }
                Spacer(minLength: 0)
                Text(E.s).font(.system(size: 44, weight: .heavy, design: .rounded))
                Text(E.nom).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(10)
            .frame(width: 112, height: 124)
            .foregroundStyle(.black)
            .background(LinearGradient(colors: [accent, accent.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: accent.opacity(0.5), radius: 14)

            VStack(alignment: .leading, spacing: 6) {
                Text(P.famille ?? "Famille inconnue").font(.headline).foregroundStyle(accent)
                Text(P.config ?? "").font(.subheadline.monospaced())
                HStack(spacing: 6) {
                    Badge(text: "Période \(P.periode ?? 0)")
                    if let g = P.groupe { Badge(text: "Groupe \(g)") }
                    if let b = P.bloc { Badge(text: "Bloc \(b)") }
                }
            }
        }
    }
}

struct Badge: View {
    let text: String
    var color: Color = .white.opacity(0.12)
    var body: some View {
        Text(text).font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

// MARK: - En un coup d'œil

struct GlanceGrid: View {
    let P: Props
    let accent: Color
    var body: some View {
        let items: [(String, String, String)] = [
            (etatIcon, "État", P.etat ?? "inconnu"),
            ("sparkles", "Origine", P.origine ?? "—"),
            ("atom", "Stabilité", (P.radioactif ?? false) ? "radioactif" : "\(P.nStables ?? 0) isotope\((P.nStables ?? 0) > 1 ? "s" : "") stable\((P.nStables ?? 0) > 1 ? "s" : "")"),
            ("text.book.closed", "Nom", P.texte?.symbolique ?? "—"),
            ("calendar", "Découverte", Fmt.siecle(P.annee)),
            ("cube", "Cristal", P.structure ?? "—"),
        ]
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(items, id: \.1) { it in
                VStack(spacing: 6) {
                    Image(systemName: it.0).font(.title2).foregroundStyle(accent).frame(height: 28)
                    Text(it.1).font(.caption2).foregroundStyle(.secondary)
                    Text(it.2).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: 96)
                .padding(6)
                .background(panelBG, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(lineColor))
            }
        }
    }
    private var etatIcon: String {
        switch P.etat {
        case "gaz": return "wind"
        case "liquide": return "drop.fill"
        case "solide": return "square.stack.3d.up.fill"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - Textes et camembert des usages

struct TextCards: View {
    let t: FicheTexte
    let accent: Color
    @State private var selected: String? = nil

    var body: some View {
        if let d = t.description {
            Card(title: "Description", icon: "text.alignleft", accent: accent) {
                Text(d).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
        }
        if t.usages != nil || t.parts != nil {
            Card(title: "Usages", icon: "wrench.and.screwdriver", accent: accent) {
                if let parts = t.parts, !parts.isEmpty { donut(parts) }
                if let u = t.usages {
                    Text(u).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func donut(_ parts: [UsagePart]) -> some View {
        let top = parts.max { $0.pct < $1.pct }
        let shown = parts.first { $0.label == selected } ?? top
        Chart(Array(parts.enumerated()), id: \.element.label) { i, p in
            SectorMark(angle: .value("Part", p.pct),
                       innerRadius: .ratio(0.58),
                       outerRadius: .ratio(p.label == shown?.label ? 1.0 : 0.92),
                       angularInset: 2)
                .cornerRadius(5)
                .foregroundStyle(chartPalette[i % chartPalette.count])
                .opacity(p.label == shown?.label ? 1 : 0.75)
        }
        .chartLegend(.hidden)
        .chartBackground { proxy in
            GeometryReader { geo in
                if let frame = proxy.plotFrame {
                    let r = geo[frame]
                    VStack(spacing: 2) {
                        Text("\(Int(shown?.pct ?? 0)) %").font(.title.bold().monospacedDigit())
                        Text(shown?.label ?? "").font(.caption2).multilineTextAlignment(.center)
                            .foregroundStyle(.secondary).frame(width: r.width * 0.5)
                    }
                    .position(x: r.midX, y: r.midY)
                }
            }
        }
        .frame(height: 230)
        .animation(.spring(duration: 0.35), value: selected)

        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parts.enumerated()), id: \.element.label) { i, p in
                Button { selected = p.label } label: {
                    HStack(spacing: 8) {
                        Circle().fill(chartPalette[i % chartPalette.count]).frame(width: 10, height: 10)
                        Text(p.label).font(.caption).foregroundStyle(.primary)
                        Spacer()
                        Text("\(Int(p.pct)) %").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        if let s = t.partsSource {
            Text(s).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Atome (modèle en couches animé)

struct AtomCard: View {
    let P: Props
    let symbol: String
    let accent: Color
    var body: some View {
        let shells = P.couches ?? []
        Card(title: "Couches électroniques", icon: "circle.circle", accent: accent) {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let maxR = min(size.width, size.height) / 2 - 6
                    let step = shells.isEmpty ? 0 : (maxR - 22) / CGFloat(shells.count)
                    // noyau
                    let nucleus = Path(ellipseIn: CGRect(x: c.x - 16, y: c.y - 16, width: 32, height: 32))
                    ctx.fill(nucleus, with: .radialGradient(Gradient(colors: [.white, accent]), center: c, startRadius: 0, endRadius: 18))
                    ctx.draw(Text(symbol).font(.caption.bold()).foregroundColor(.black), at: c)
                    for (i, count) in shells.enumerated() {
                        let r = 22 + step * CGFloat(i + 1)
                        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                                   with: .color(.white.opacity(0.18)), lineWidth: 1)
                        let speed = 0.5 / Double(i + 1)
                        for k in 0..<count {
                            let a = Double(k) / Double(count) * 2 * .pi + t * speed * (i % 2 == 0 ? 1 : -1)
                            let p = CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
                            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.6, y: p.y - 2.6, width: 5.2, height: 5.2)),
                                     with: .color(accent))
                        }
                    }
                }
            }
            .frame(height: 260)

            HStack(spacing: 6) {
                ForEach(Array(shells.enumerated()), id: \.offset) { i, c in
                    VStack(spacing: 2) {
                        Text(String(Array("KLMNOPQ")[min(i, 6)])).font(.caption2.bold()).foregroundStyle(accent)
                        Text("\(c)").font(.callout.bold().monospacedDigit())
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            if let c = P.config { ValueRow(label: "Configuration", value: c) }
        }
    }
}

// MARK: - Énergies d'ionisation

struct IonisationCard: View {
    let ei: [Double]
    let accent: Color
    var body: some View {
        Card(title: "Énergies d'ionisation", icon: "bolt.fill", accent: accent) {
            Chart(Array(ei.enumerated()), id: \.offset) { i, v in
                AreaMark(x: .value("Ionisation", i + 1), y: .value("kJ/mol", v))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [accent.opacity(0.45), accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Ionisation", i + 1), y: .value("kJ/mol", v))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("Ionisation", i + 1), y: .value("kJ/mol", v))
                    .foregroundStyle(.white)
                    .symbolSize(28)
            }
            .chartXAxis {
                AxisMarks(values: Array(1...ei.count)) { v in
                    AxisValueLabel { if let k = v.as(Int.self) { Text("\(k)e") } }
                }
            }
            .chartYAxisLabel("kJ/mol")
            .frame(height: 190)
            Text("Énergie à fournir pour arracher les électrons un par un. Un saut brutal signale qu'on attaque une couche plus profonde.")
                .font(.caption).foregroundStyle(.secondary)
            ValueRow(label: "1re ionisation", value: Fmt.unit(ei.first, "kJ/mol", 4))
        }
    }
}

// MARK: - Tendance périodique

struct TrendCard: View {
    let n: Int
    let accent: Color
    enum Prop: String, CaseIterable, Identifiable {
        case densite = "Densité", fusion = "Fusion", en = "Électronég.", rayon = "Rayon"
        var id: String { rawValue }
        var unite: String {
            switch self {
            case .densite: return "g/cm³"
            case .fusion: return "K"
            case .en: return "Pauling"
            case .rayon: return "pm"
            }
        }
        func value(_ p: Props) -> Double? {
            switch self {
            case .densite: return p.densite
            case .fusion: return p.fusion
            case .en: return p.enPauling
            case .rayon: return p.rayonAt
            }
        }
    }
    @State private var prop: Prop = .densite

    var body: some View {
        let pts = (1...118).compactMap { z -> (Int, Double)? in
            guard let p = PropsStore.get(z), let v = prop.value(p) else { return nil }
            return (z, v)
        }
        let mine = pts.first { $0.0 == n }
        let rank = mine.map { m in pts.filter { $0.1 > m.1 }.count + 1 }
        Card(title: "Parmi les 118 éléments", icon: "chart.xyaxis.line", accent: accent) {
            Picker("Propriété", selection: $prop) {
                ForEach(Prop.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Chart {
                ForEach(pts, id: \.0) { z, v in
                    LineMark(x: .value("Z", z), y: .value(prop.unite, v))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1.2))
                }
                if let m = mine {
                    RuleMark(x: .value("Z", m.0))
                        .foregroundStyle(accent.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    PointMark(x: .value("Z", m.0), y: .value(prop.unite, m.1))
                        .foregroundStyle(accent)
                        .symbolSize(140)
                        .annotation(position: .top) {
                            Text(Fmt.num(m.1)).font(.caption2.bold()).padding(4)
                                .background(accent.opacity(0.25), in: RoundedRectangle(cornerRadius: 5))
                        }
                }
            }
            .chartXScale(domain: 1...118)
            .chartYAxisLabel(prop.unite)
            .frame(height: 200)
            .animation(.easeInOut, value: prop)

            if let rank {
                Text("Rang \(rank) sur \(pts.count) pour « \(prop.rawValue.lowercased()) » (du plus élevé au plus faible).")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Valeur inconnue pour cet élément.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Propriétés physiques

struct PhysiqueCard: View {
    let P: Props
    var body: some View {
        Card(title: "Propriétés physiques", icon: "thermometer.medium") {
            ThermoBar(fusion: P.fusion, ebullition: P.ebullition)
            ValueRow(label: "Fusion", value: Fmt.celsius(P.fusion))
            ValueRow(label: "Ébullition", value: Fmt.celsius(P.ebullition))
            ValueRow(label: "Masse volumique", value: P.densite.map { Fmt.num($0 * 1000, 4) + " kg/m³" } ?? "—")
            ValueRow(label: "Volume molaire", value: Fmt.unit(P.volMol, "cm³/mol"))
            ValueRow(label: "Enthalpie de fusion", value: Fmt.unit(P.hFusion, "kJ/mol"))
            ValueRow(label: "Enthalpie de vaporisation", value: Fmt.unit(P.hVap, "kJ/mol"))
            ValueRow(label: "Capacité thermique", value: Fmt.unit(P.capa, "J/g/K"))
            ValueRow(label: "Conductivité thermique", value: Fmt.unit(P.cond, "W/m/K"))
        }
    }
}

/// Barre de température : solide → liquide → gaz, avec la température ambiante.
struct ThermoBar: View {
    let fusion: Double?
    let ebullition: Double?
    var body: some View {
        let maxT = max(6000, (ebullition ?? 0) * 1.05)
        GeometryReader { geo in
            let w = geo.size.width
            let x: (Double) -> CGFloat = { CGFloat(log10(max($0, 1)) / log10(maxT)) * w }
            ZStack(alignment: .leading) {
                Capsule().fill(LinearGradient(colors: [Color(hex: 0x4dabf7), Color(hex: 0xffa94d), Color(hex: 0xff6b6b)],
                                              startPoint: .leading, endPoint: .trailing)).frame(height: 10)
                if let f = fusion { marker(x(f), "fusion") }
                if let e = ebullition { marker(x(e), "ébullition") }
                Rectangle().fill(.white).frame(width: 2, height: 22).offset(x: x(298) - 1)
                Text("25 °C").font(.system(size: 9)).offset(x: x(298) - 12, y: 18)
            }
        }
        .frame(height: 44)
    }
    private func marker(_ px: CGFloat, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
            Image(systemName: "arrowtriangle.down.fill").font(.system(size: 9))
        }
        .offset(x: px - 16, y: -16)
    }
}

// MARK: - Propriétés chimiques

struct ChimieCard: View {
    let P: Props
    let accent: Color
    var body: some View {
        let raw: [(String, Double?)] = [("Mesuré", P.rayonAt), ("Calculé", P.rayonCalc), ("Covalent", P.rayonCov),
                                         ("Van der Waals", P.rayonVdw), ("Métallique", P.rayonMet)]
        let radii: [(String, Double)] = raw.compactMap { item -> (String, Double)? in
            guard let v = item.1 else { return nil }
            return (item.0, v)
        }
        Card(title: "Propriétés chimiques", icon: "flask", accent: accent) {
            HStack(spacing: 10) {
                Gauge(value: min(P.enPauling ?? 0, 4), in: 0...4) {
                    Text("EN")
                } currentValueLabel: { Text(Fmt.num(P.enPauling, 3)) }
                .gaugeStyle(.accessoryCircular).tint(Gradient(colors: [.blue, .purple, .pink]))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Électronégativité (Pauling)").font(.subheadline.weight(.semibold))
                    Text("Tendance à attirer les électrons d'une liaison. Échelle de 0,7 (césium) à 4 (fluor).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ValueRow(label: "Électronégativité (Allen)", value: Fmt.num(P.enAllen, 4))
            ValueRow(label: "Affinité électronique", value: Fmt.unit(P.ae, "kJ/mol"))
            ValueRow(label: "États d'oxydation", value: (P.oxy ?? []).map { $0 > 0 ? "+\($0)" : "\($0)" }.joined(separator: ", ").ifEmpty("—"))
            if !radii.isEmpty {
                Text("Rayons atomiques (pm)").font(.subheadline.weight(.semibold)).padding(.top, 4)
                Chart(radii, id: \.0) { l, v in
                    BarMark(x: .value("pm", v), y: .value("Type", l))
                        .foregroundStyle(LinearGradient(colors: [accent.opacity(0.5), accent], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(4)
                        .annotation(position: .trailing) { Text(Fmt.num(v)).font(.caption2.monospacedDigit()) }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(radii.count) * 30)
            }
        }
    }
}

extension String {
    func ifEmpty(_ s: String) -> String { isEmpty ? s : self }
}

// MARK: - Isotopes

struct IsotopesCard: View {
    let P: Props
    let symbol: String
    let accent: Color
    var body: some View {
        let isos = P.isotopes ?? []
        let natural = isos.filter { ($0.ab ?? 0) > 0 }
        let counts: [(String, Int)] = [("Stables", P.nStables ?? 0), ("β⁺ / CE", P.nBplus ?? 0),
                                       ("β⁻", P.nBmoins ?? 0), ("α", P.nAlpha ?? 0)]
        Card(title: "Isotopes", icon: "circle.hexagongrid", accent: accent) {
            Text("\(P.nIso ?? 0) isotopes connus").font(.subheadline.weight(.semibold))
            Chart(counts, id: \.0) { l, v in
                BarMark(x: .value("Type", l), y: .value("Nombre", v))
                    .foregroundStyle(l == "Stables" ? Color(hex: 0x38d9a9) : accent)
                    .cornerRadius(5)
                    .annotation(position: .top) { Text("\(v)").font(.caption2.bold()) }
            }
            .chartYAxis(.hidden)
            .frame(height: 140)

            if !natural.isEmpty {
                Text("Abondance naturelle").font(.subheadline.weight(.semibold)).padding(.top, 4)
                Chart(natural, id: \.a) { iso in
                    BarMark(x: .value("Isotope", "\(iso.a)"), y: .value("%", iso.ab ?? 0))
                        .foregroundStyle(LinearGradient(colors: [accent, accent.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(5)
                        .annotation(position: .top) { Text(Fmt.num(iso.ab, 3) + " %").font(.system(size: 9).monospacedDigit()) }
                }
                .chartYAxis(.hidden)
                .frame(height: 170)
            }

            Text("Principaux isotopes").font(.subheadline.weight(.semibold)).padding(.top, 4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 6)], spacing: 6) {
                ForEach(isos, id: \.a) { iso in IsotopeTile(iso: iso, z: P.n, symbol: symbol, accent: accent) }
            }
            Text("CE : capture électronique · FS : fission spontanée").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct IsotopeTile: View {
    let iso: Isotope
    let z: Int
    let symbol: String
    let accent: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text("\(iso.a)").font(.system(size: 10, weight: .bold).monospacedDigit())
                Spacer()
                Text(Fmt.num(iso.m, 6)).font(.system(size: 8).monospacedDigit())
            }
            Text(symbol).font(.system(size: 22, weight: .heavy, design: .rounded)).frame(maxWidth: .infinity)
            Text(iso.stable ? "stable" : (iso.mode ?? []).prefix(2).joined(separator: " ")).font(.system(size: 9, weight: .semibold))
                .frame(maxWidth: .infinity)
            Text(iso.stable ? " " : (iso.demi ?? "?")).font(.system(size: 8)).lineLimit(1).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
            Text(iso.ab.map { Fmt.num($0, 3) + " %" } ?? "0 %").font(.system(size: 8).monospacedDigit())
                .frame(maxWidth: .infinity)
        }
        .padding(5)
        .foregroundStyle(.black)
        .background(iso.stable ? Color(hex: 0x38d9a9) : accent.opacity(lifeOpacity), in: RoundedRectangle(cornerRadius: 8))
    }
    /// Plus la demi-vie est longue, plus la case est vive.
    private var lifeOpacity: Double {
        guard let s = iso.s, s > 0 else { return 0.4 }
        return min(1, max(0.4, 0.4 + log10(s) / 30))
    }
}

// MARK: - Abondance et ressources

struct AbondanceCard: View {
    let P: Props
    let accent: Color
    var body: some View {
        Card(title: "Abondance et ressources", icon: "globe.europe.africa", accent: accent) {
            LogGauge(label: "Croûte terrestre", value: P.croute, text: Fmt.ppm(P.croute), accent: accent)
            LogGauge(label: "Eau de mer", value: P.mer, text: P.mer.map { Fmt.num($0 * 1000, 3) + " µg/L" } ?? "—", accent: Color(hex: 0x4dabf7))
            if let prod = P.producteurs, !prod.isEmpty { Podium(title: "Premiers producteurs", pays: prod, accent: accent) }
            if let res = P.reserves, !res.isEmpty { ValueRow(label: "Principales réserves", value: res.joined(separator: ", ")) }
            if let c = P.concentration { ValueRow(label: "Part du 1er producteur", value: Fmt.num(c) + " %") }
            if let p = P.prix { ValueRow(label: "Prix indicatif", value: Fmt.num(p) + " $/kg") }
            if let r = P.recyclage { ValueRow(label: "Taux de recyclage", value: r.replacingOccurrences(of: "<", with: "< ").replacingOccurrences(of: ">", with: "> ") + " %") }
            if let risk = P.risque {
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Risque d'approvisionnement").font(.subheadline).foregroundStyle(.secondary); Spacer(); Text(Fmt.num(risk, 2) + " / 10").font(.subheadline.bold()) }
                    Gauge(value: risk, in: 0...10) { EmptyView() }
                        .gaugeStyle(.accessoryLinear)
                        .tint(Gradient(colors: [.green, .yellow, .red]))
                }
            }
        }
    }
}

/// Jauge logarithmique de 1 ng/kg à 1 000 000 mg/kg.
struct LogGauge: View {
    let label: String
    let value: Double?
    let text: String
    let accent: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(label).font(.subheadline).foregroundStyle(.secondary); Spacer(); Text(text).font(.subheadline.bold()) }
            GeometryReader { geo in
                let frac = value.map { min(1, max(0.02, (log10(max($0, 1e-9)) + 9) / 15)) } ?? 0
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule().fill(LinearGradient(colors: [accent.opacity(0.4), accent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * frac)
                }
            }
            .frame(height: 8)
        }
    }
}

struct Podium: View {
    let title: String
    let pays: [String]
    let accent: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(order, id: \.self) { i in
                    if i < pays.count {
                        VStack(spacing: 4) {
                            Text(pays[i]).font(.caption2.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                            Text("\(i + 1)").font(.headline.bold()).foregroundStyle(.black)
                                .frame(maxWidth: .infinity, minHeight: [64, 46, 32][i])
                                .background(accent.opacity([1, 0.75, 0.55][i]), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
    private var order: [Int] { [1, 0, 2] }
}

// MARK: - Histoire

struct HistoireCard: View {
    let P: Props
    let accent: Color
    var body: some View {
        Card(title: "Histoire et nom", icon: "scroll", accent: accent) {
            DiscoveryTimeline(annee: P.annee, accent: accent)
            ValueRow(label: "Découverte", value: P.annee.map { "\($0)" } ?? "Antiquité")
            if let d = P.texte?.decouvreurs ?? P.decouvreursEn {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Découvreurs").font(.subheadline).foregroundStyle(.secondary)
                    Text(d).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let e = P.texte?.etymologie {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Étymologie").font(.subheadline).foregroundStyle(.secondary)
                    Text(e).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Frise des découvertes : chaque élément est un point, celui-ci est mis en avant.
struct DiscoveryTimeline: View {
    let annee: Int?
    let accent: Color
    var body: some View {
        let years = PropsStore.all.values.compactMap(\.annee).filter { $0 >= 1600 }
        Chart {
            ForEach(Array(years.enumerated()), id: \.offset) { _, y in
                PointMark(x: .value("Année", y), y: .value("", 0))
                    .symbolSize(18).foregroundStyle(.white.opacity(0.3))
            }
            if let a = annee, a >= 1600 {
                PointMark(x: .value("Année", a), y: .value("", 0))
                    .symbolSize(160).foregroundStyle(accent)
                    .annotation(position: .top) { Text("\(a)").font(.caption.bold()) }
            }
        }
        .chartXScale(domain: 1600...2025)
        .chartYAxis(.hidden)
        .chartXAxis { AxisMarks(values: [1600, 1700, 1800, 1900, 2000]) }
        .frame(height: 80)
    }
}

// MARK: - SGH

struct SGHCard: View {
    let items: [Pictogramme]
    var body: some View {
        Card(title: "Sécurité (SGH)", icon: "exclamationmark.triangle", accent: .red) {
            ForEach(items, id: \.code) { p in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: 40, height: 40)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.red, lineWidth: 4))
                            .rotationEffect(.degrees(45))
                        Image(systemName: icon(p.code)).font(.title3).foregroundStyle(.black)
                    }
                    .frame(width: 60, height: 60)
                    VStack(alignment: .leading) {
                        Text(p.code).font(.headline)
                        Text(p.label).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    private func icon(_ code: String) -> String {
        switch code {
        case "SGH01": return "burst.fill"
        case "SGH02": return "flame.fill"
        case "SGH03": return "flame.circle"
        case "SGH04": return "cylinder.split.1x2"
        case "SGH05": return "drop.triangle.fill"
        case "SGH06": return "staroflife.fill"
        case "SGH07": return "exclamationmark"
        case "SGH08": return "figure.stand"
        case "SGH09": return "leaf.fill"
        default: return "questionmark"
        }
    }
}
