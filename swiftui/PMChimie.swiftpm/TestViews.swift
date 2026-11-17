import SwiftUI

struct TestBar: View {
    @Environment(PalaceModel.self) private var model
    var body: some View {
        HStack {
            if let s = model.session {
                VStack(alignment: .leading, spacing: 0) {
                    Text(s.title).font(.headline)
                    Text(s.progressText).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer()
            Button("Quitter") { model.endSession() }
                .buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}

private struct BigButton: View {
    let title: String
    var style: Style = .primary
    let action: () -> Void
    enum Style { case primary, ok, bad, plain }
    var body: some View {
        Button(action: action) {
            Text(title).font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 46)
        }
        .foregroundStyle(.white)
        .background(color, in: RoundedRectangle(cornerRadius: 12))
    }
    private var color: Color {
        switch style {
        case .primary: return .copper
        case .ok: return Color(hex: 0x2e7d32)
        case .bad: return Color(hex: 0xc62828)
        case .plain: return Color.white.opacity(0.14)
        }
    }
}

/// Carte posée sur la 3D tant que la réponse n'est pas révélée.
struct QuestionCard: View {
    @Environment(PalaceModel.self) private var model
    let card: TestCard
    let session: TestSession
    @State private var typed = ""
    @FocusState private var focused: Bool

    var body: some View {
        let n = card.n
        Group {
            switch card.kind {
            case .rehearse, .n2i:
                VStack(spacing: 10) {
                    kindLabel(card.kind == .rehearse ? "Rappel" : "Numéro → image")
                    Text("\(n)").font(.system(size: 56, weight: .heavy).monospacedDigit())
                    Text("Quelle image est à l'emplacement \(n) ?").font(.headline).multilineTextAlignment(.center)
                    Text("Visualise-la à sa place, puis révèle.").font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    BigButton(title: "Révéler") { model.reveal() }
                }
            case .i2n:
                VStack(spacing: 10) {
                    kindLabel("Image → numéro")
                    Thumb(n: n, size: 150)
                    Text("À quel numéro est cette image ?").font(.headline)
                    TextField("Numéro", text: $typed)
                        .keyboardType(.numberPad)
                        .focused($focused)
                        .multilineTextAlignment(.center)
                        .font(.title2.monospacedDigit())
                        .padding(8)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .onSubmit(submit)
                    HStack {
                        BigButton(title: "Je ne sais pas", style: .plain) { typed = ""; model.answer(nil) }
                        BigButton(title: "Valider") { submit() }
                    }
                }
                .onAppear { typed = ""; focused = true }
            case .suite, .chainStep:
                VStack(spacing: 10) {
                    kindLabel(card.kind == .suite ? "Suite" : "Chaîne")
                    Thumb(n: n, size: 130)
                    Text("\(n) · \(PM.elements[n].nom)\nQuelle image vient ensuite ?").font(.headline).multilineTextAlignment(.center)
                    Text("Retrouve l'action qui relie cette image à la suivante.").font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                    BigButton(title: "Révéler") { model.reveal() }
                }
            default:
                EmptyView()
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: 380)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .environment(\.colorScheme, .dark)
        .padding()
        .id(session.done * 1000 + n + (card.kind == .i2n ? 500 : 0))
    }

    private func kindLabel(_ s: String) -> some View {
        Text(s.uppercased()).font(.caption.weight(.bold)).tracking(1).foregroundStyle(Color.glowOrange)
    }

    private func submit() {
        let v = Int(typed.trimmingCharacters(in: .whitespaces))
        typed = ""
        focused = false
        model.answer(v)
    }
}

/// Boutons sous la 3D pendant une séance.
struct TestControls: View {
    @Environment(PalaceModel.self) private var model
    var body: some View {
        if let s = model.session, let c = s.current {
            VStack(alignment: .leading, spacing: 8) {
                switch c.kind {
                case .present:
                    Text("Nouvel élément · \(c.n) \(PM.elements[c.n].nom)").font(.headline)
                    if c.n > 0 {
                        Text("Lien depuis \(c.n - 1) · \(PM.elements[c.n - 1].nom) : \(PM.elements[c.n - 1].lien)")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                    }
                    BigButton(title: "C'est noté") { model.nextCard() }
                case .chainStart:
                    Text("Chaîne \(s.chainA)–\(s.chainB) · départ").font(.headline)
                    Text("Récite de proche en proche, puis révèle chaque image.").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    BigButton(title: "Commencer") { model.nextCard() }
                default:
                    if s.revealed {
                        let target = (c.kind == .suite || c.kind == .chainStep) ? c.n + 1 : c.n
                        let wrong = s.autoResult == false
                        Text("Réponse · \(target) \(PM.elements[target].nom)" + (wrong && s.typed != nil ? " · tu as répondu \(s.typed!)" : ""))
                            .font(.headline)
                        if let ok = s.autoResult {
                            HStack {
                                Text(ok ? "Bonne réponse" : "C'était \(c.n)")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background(ok ? Color(hex: 0x2e7d32) : Color(hex: 0xc62828), in: RoundedRectangle(cornerRadius: 12))
                                BigButton(title: "Suivant") { model.nextCard() }
                            }
                        } else {
                            HStack {
                                BigButton(title: "Raté", style: .bad) { model.judge(false) }
                                BigButton(title: "Je savais", style: .ok) { model.judge(true) }
                            }
                        }
                    } else {
                        EmptyView()
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Menu des tests

struct TestsSheet: View {
    @Environment(PalaceModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var notice: String? = nil
    @State private var confirmReset = false

    var body: some View {
        let srs = model.srs
        let newCount = srs.newNums().count
        let dueCount = srs.dueCards().count
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let m = model.endMessage {
                        Text(m).font(.headline).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.copper.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Dizaines").font(.headline)
                            Spacer()
                            Button("Tout") { srs.selectAll(true) }
                            Button("Aucune") { srs.selectAll(false) }
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                            ForEach(0..<SRSStore.dzCount, id: \.self) { d in
                                let on = srs.sel.contains(d)
                                Button { srs.toggle(d) } label: {
                                    HStack(spacing: 4) {
                                        Circle().fill(PM.dizColor(d)).frame(width: 10, height: 10)
                                        Text("\(d)x").font(.caption.bold().monospacedDigit())
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 32)
                                    .background(on ? Color.copper : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(.white)
                                }
                                .accessibilityLabel("Dizaine \(d)x, \(on ? "sélectionnée" : "non sélectionnée")")
                            }
                        }
                        Stepper("Nouveaux par séance : \(srs.newPer)", value: Binding(get: { srs.newPer }, set: { srs.setNewPer($0) }), in: 2...30)
                            .font(.subheadline)
                    }

                    if let notice { Text(notice).font(.subheadline).foregroundStyle(Color.glowOrange) }

                    VStack(spacing: 8) {
                        testButton(.learn, "Apprentissage progressif",
                                   newCount > 0 ? "\(min(newCount, srs.newPer)) nouveaux sur \(newCount) restants, avec leur lien depuis l'élément précédent"
                                                : "Tous les éléments sélectionnés sont déjà appris", icon: "sparkles")
                        testButton(.review, "Révision du jour",
                                   dueCount > 0 ? "\(dueCount) fiche\(dueCount > 1 ? "s" : "") à revoir aujourd'hui"
                                                : "Rien à revoir aujourd'hui dans cette sélection", icon: "calendar")
                        testButton(.n2i, "Numéro → image", "Visualise l'image d'un emplacement", icon: "number")
                        testButton(.i2n, "Image → numéro", "Retrouve l'emplacement d'une image", icon: "photo")
                        testButton(.suite, "Suite", "Quelle image vient après celle-ci ?", icon: "arrow.right")
                        testButton(.chain, "Chaîne", "Récite toute une dizaine de proche en proche", icon: "link")
                    }

                    ProgressGrid(srs: srs)

                    Button(role: .destructive) { confirmReset = true } label: {
                        Text("Remettre la progression à zéro").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .confirmationDialog("Effacer toute la progression ?", isPresented: $confirmReset, titleVisibility: .visible) {
                        Button("Tout effacer", role: .destructive) { srs.reset() }
                    }
                }
                .padding()
            }
            .navigationTitle("Tests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
        }
    }

    private func testButton(_ kind: TestSession.Kind, _ title: String, _ sub: String, icon: String) -> some View {
        Button {
            if let msg = model.startSession(kind) { notice = msg } else { notice = nil }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3).frame(width: 30).foregroundStyle(Color.glowOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(sub).font(.caption).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.4))
            }
            .padding(12)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
        }
    }
}

/// Grille de progression : en haut l'emplacement, en bas le lien vers le suivant.
struct ProgressGrid: View {
    let srs: SRSStore
    private func col(_ c: SRSStore.Card?) -> Color { c.map { Color(hex: SRSStore.boxColors[$0.box]) } ?? .clear }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Progression").font(.headline)
            ForEach(0..<SRSStore.dzCount, id: \.self) { d in
                HStack(spacing: 3) {
                    Text("\(d)x").font(.caption2.monospacedDigit()).frame(width: 26, alignment: .leading).foregroundStyle(.white.opacity(0.6))
                    ForEach(0..<10, id: \.self) { k in
                        let n = d * 10 + k
                        if n <= PM.maxN {
                            VStack(spacing: 1) {
                                Rectangle().fill(col(srs.card("P\(n)")))
                                Rectangle().fill(n < PM.maxN ? col(srs.card("L\(n)")) : .clear)
                            }
                            .frame(maxWidth: .infinity, minHeight: 22)
                            .overlay(Text("\(n)").font(.system(size: 8).monospacedDigit()).foregroundStyle(.white.opacity(0.8)))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(lineColor))
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 22)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                ForEach(Array(["à revoir", "1 j", "2 j", "4 j", "8 j", "16 j"].enumerated()), id: \.offset) { item in
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2).fill(Color(hex: SRSStore.boxColors[item.offset])).frame(width: 10, height: 10)
                        Text(item.element).font(.caption2)
                    }
                }
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.top, 4)
        }
    }
}
