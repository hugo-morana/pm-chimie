import SwiftUI

/// Pastille numéro + symbole aux couleurs de la dizaine (fond) et de l'unité (bandeau).
struct Tile: View {
    let n: Int
    var masked = false
    var size: CGFloat = 54
    var body: some View {
        let d = (n % 100) / 10, u = n % 10
        let bgHex: UInt32 = masked ? 0x888888 : PM.dizHex[d]
        VStack(spacing: 0) {
            Text(masked ? "?" : "\(n)")
                .font(.system(size: size * 0.36, weight: .heavy).monospacedDigit())
                .contentTransition(.numericText(value: Double(n)))
            Text(masked ? "?" : PM.elements[n].s)
                .font(.system(size: size * 0.26, weight: .semibold))
        }
        .foregroundStyle(PM.isDark(bgHex) ? Color.white : Color.black)
        .frame(width: size, height: size)
        .background(Color(hex: bgHex))
        .overlay(alignment: .bottom) {
            Rectangle().fill(masked ? Color(hex: 0x888888) : PM.dizColor(u)).frame(height: size * 0.12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.5), lineWidth: 1))
    }
}

struct Thumb: View {
    let n: Int
    var hidden = false
    var size: CGFloat = 64
    var body: some View {
        Group {
            if hidden {
                Color.black
            } else {
                Image(uiImage: ImageStore.shared.image(n)).resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(lineColor))
    }
}

struct FicheView: View {
    @Environment(PalaceModel.self) private var model
    @State private var lightbox: LightboxItem? = nil
    @State private var detail: LightboxItem? = nil
    @Namespace private var zoomNS

    var body: some View {
        let T = model.testLook
        let n = model.n
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(.easeOut(duration: 0.2)) { model.ficheCollapsed.toggle() } } label: {
                Capsule().fill(.white.opacity(0.3)).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.vertical, 2)
            }
            .accessibilityLabel(model.ficheCollapsed ? "Déplier la fiche" : "Replier la fiche")

            if n < 0 {
                let R = Palace.rooms[model.room]
                (Text(R.name).bold() + Text(" · \(R.range). Appuie sur › pour commencer à l'emplacement \(R.first)."))
                    .font(.subheadline)
            } else {
                header(n, T)
                if !model.ficheCollapsed && !(T?.compact ?? false) {
                    ScrollView {
                        details(n).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 230)
                }
            }
        }
        .padding(.horizontal, 14).padding(.bottom, 10).padding(.top, 4)
        .foregroundStyle(.white)
        .background(panelBG.ignoresSafeArea(edges: .bottom))
        .onChange(of: model.detailRequest) { _, r in
            if let r { detail = LightboxItem(n: r); model.detailRequest = nil }
        }
        .sheet(item: $detail) { item in ElementDetailView(n: item.n).zoomDestination(item.n, in: zoomNS) }
        .fullScreenCover(item: $lightbox) { item in
            Lightbox(n: item.n, masked: (T?.mask ?? false) && item.n == n) { lightbox = nil }
        }
    }

    @ViewBuilder
    private func header(_ n: Int, _ T: TestLook?) -> some View {
        let E = PM.elements[n]
        let mask = T?.mask ?? false
        HStack(alignment: .center, spacing: 12) {
            Tile(n: n, masked: T?.maskAll ?? false)
            VStack(alignment: .leading, spacing: 2) {
                if !(T?.maskAll ?? false) {
                    Text(PM.whereText(n)).font(.caption).foregroundStyle(.white.opacity(0.65)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Text(mask ? "?" : E.nom).font(.title3.bold())
                if !mask { Text(E.img).font(.subheadline).foregroundStyle(.white.opacity(0.85)).lineLimit(2) }
            }
            Spacer(minLength: 0)
            let hidden = T?.hideImg == n
            Button { if !hidden { lightbox = LightboxItem(n: n) } } label: { Thumb(n: n, hidden: hidden) }
                .accessibilityLabel("Agrandir l'image")
        }
        .animation(.snappy(duration: 0.35), value: n)
    }

    @ViewBuilder
    private func details(_ n: Int) -> some View {
        let E = PM.elements[n]
        VStack(alignment: .leading, spacing: 12) {
            Text(E.deco).font(.subheadline).foregroundStyle(.white.opacity(0.85))
            if PropsStore.get(n) != nil {
                Button { detail = LightboxItem(n: n) } label: {
                    Label("Fiche complète : propriétés, usages, isotopes", systemImage: "chart.pie.fill")
                        .symbolEffect(.bounce, value: n)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.copper.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                        .shimmer(period: 4, cornerRadius: 10)
                }
                .buttonStyle(PressableStyle())
                .zoomSource(n, in: zoomNS)
            }
            if n < PM.maxN {
                linkRow(img: n + 1, label: "⟶ vers \(n + 1) · \(PM.elements[n + 1].nom)", text: E.lien)
            }
            if n > 0 {
                linkRow(img: n - 1, label: "⟵ depuis \(n - 1) · \(PM.elements[n - 1].nom)", text: PM.elements[n - 1].lien)
            }
        }
    }

    private func linkRow(img: Int, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { lightbox = LightboxItem(n: img) } label: { Thumb(n: img, size: 48) }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption.bold()).foregroundStyle(Color.glowOrange)
                Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct LightboxItem: Identifiable { let n: Int; var id: Int { n } }

struct Lightbox: View {
    let n: Int
    let masked: Bool
    let close: () -> Void
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(uiImage: ImageStore.shared.image(n)).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14)).padding()
                if !masked { Text("\(n) · \(PM.elements[n].nom)").font(.title3.bold()).foregroundStyle(.white) }
            }
        }
        .onTapGesture(perform: close)
    }
}

// MARK: - Plan

struct PlanSheet: View {
    @Environment(PalaceModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Palace.rooms, id: \.id) { R in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(R.name) · \(R.range)").font(.headline)
                            ForEach(0..<10, id: \.self) { d in
                                let base = R.id * 100 + d * 10
                                if base <= PM.maxN {
                                    HStack(spacing: 4) {
                                        Text((R.alchemist ? "1" : "") + "\(d)x")
                                            .font(.caption2.bold().monospacedDigit()).frame(width: 30, alignment: .leading)
                                            .foregroundStyle(.white.opacity(0.7))
                                        ForEach(0..<10, id: \.self) { k in cell(base + k, d: d) }
                                    }
                                    Text(PM.surfName[d] + " · " + PM.dizName[d])
                                        .font(.caption2).foregroundStyle(.white.opacity(0.5)).padding(.leading, 34)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
        }
    }

    @ViewBuilder
    private func cell(_ n: Int, d: Int) -> some View {
        if n <= PM.maxN {
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { model.go(n) }
            } label: {
                VStack(spacing: 0) {
                    Text("\(n)").font(.system(size: 10, weight: .bold).monospacedDigit())
                    Text(PM.elements[n].s).font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(PM.isDark(PM.dizHex[d]) ? Color.white : Color.black)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(PM.dizColor(d), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(model.n == n ? Color.glowOrange : .clear, lineWidth: 2.5))
            }
            .accessibilityLabel("\(n) \(PM.elements[n].nom)")
        } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: 36)
        }
    }
}
