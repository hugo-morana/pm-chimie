import SwiftUI
import SceneKit

@main
struct PMChimieApp: App {
    @State private var model = PalaceModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(.copper)
        }
    }
}

let panelBG = Color(hex: 0x1f2328)
let lineColor = Color.white.opacity(0.14)

struct ContentView: View {
    @Environment(PalaceModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            if model.session != nil { TestBar() } else { TopBar() }
            ZStack {
                SceneHost()
                SceneOverlays()
            }
            .clipped()
            if model.session == nil { NavBar() }
            if model.session != nil { TestControls() }
            FicheView()
        }
        .background(Color(hex: 0x15171a).ignoresSafeArea())
        .sheet(isPresented: $model.showTests, onDismiss: { model.endMessage = nil }) { TestsSheet() }
        .sheet(isPresented: $model.showPlan) { PlanSheet() }
    }
}

// MARK: - Vue SceneKit

struct SceneHost: View {
    @Environment(PalaceModel.self) private var model
    var body: some View {
        GeometryReader { geo in
            SCNViewBox(controller: model.scene)
                .onChange(of: geo.size, initial: true) { _, size in
                    guard size.width > 0, size.height > 0 else { return }
                    DispatchQueue.main.async {
                        model.startIfNeeded()
                        model.reframe()
                    }
                }
        }
    }
}

struct SCNViewBox: UIViewRepresentable {
    let controller: SceneController
    func makeUIView(context: Context) -> SCNView { controller.view }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

// MARK: - Barres

struct TopBar: View {
    @Environment(PalaceModel.self) private var model
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Palace.rooms, id: \.id) { r in
                Button { model.goRoom(r.id) } label: {
                    VStack(spacing: 0) {
                        Text(r.short).font(.footnote.bold()).lineLimit(1).minimumScaleFactor(0.7)
                        Text(r.range).font(.caption2.monospacedDigit()).opacity(0.8)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(model.room == r.id ? Color.copper : panelBG, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
                }
            }
            Menu {
                Button { model.setMode(.guided) } label: { Label("Visite guidée", systemImage: "figure.walk.motion") }
                Button { model.setMode(.free) } label: { Label("Visite libre", systemImage: "gamecontroller") }
            } label: {
                Image(systemName: model.mode == .free ? "gamecontroller.fill" : "figure.walk.motion")
                    .frame(width: 38, height: 38).background(panelBG, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Mode de visite")
            Button { model.showPlan = true } label: {
                Image(systemName: "map").frame(width: 38, height: 38).background(panelBG, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Plan")
            Button { model.showTests = true } label: {
                Image(systemName: "checklist").frame(width: 38, height: 38).background(panelBG, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Tests")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 6)
    }
}

struct NavBar: View {
    @Environment(PalaceModel.self) private var model
    var body: some View {
        HStack(spacing: 8) {
            navButton("chevron.left.2", "Dizaine précédente") { model.stepD(-1) }
            navButton("chevron.left", "Élément précédent") { model.stepN(-1) }
            Button { model.cycleZoom() } label: {
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { k in
                            Circle().fill(k <= model.lvl && model.mode == .guided ? Color.copper : Color.white.opacity(0.25))
                                .frame(width: 6, height: 6)
                        }
                    }
                    Text(model.mode == .free ? "Visite libre" : PalaceModel.zoomNames[model.lvl])
                        .font(.caption.weight(.semibold)).lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(panelBG, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Changer le zoom")
            navButton("chevron.right", "Élément suivant") { model.stepN(1) }
            navButton("chevron.right.2", "Dizaine suivante") { model.stepD(1) }
            Button { model.toggleChain() } label: {
                Image(systemName: "link")
                    .frame(width: 44, height: 44)
                    .background(model.showChain ? Color.copper : panelBG, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel(model.showChain ? "Masquer la chaîne" : "Afficher la chaîne")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 6)
    }

    private func navButton(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.headline)
                .frame(width: 44, height: 44)
                .background(panelBG, in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Superpositions sur la 3D

struct SceneOverlays: View {
    @Environment(PalaceModel.self) private var model
    var body: some View {
        ZStack {
            VStack {
                if let a = model.bannerFrom, a < PM.maxN {
                    LinkBanner(a: a).transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                if model.mode == .guided && model.lvl == 0 && model.session == nil {
                    Legend(alch: model.room == 1)
                }
            }
            .padding(8)
            .animation(.easeOut(duration: 0.25), value: model.bannerFrom)

            if model.mode == .free && model.session == nil {
                VStack {
                    Spacer()
                    HStack {
                        Joystick { model.scene.setJoystick($0) }
                        Spacer()
                        Text("Glisse pour regarder,\ntouche une image pour t'en approcher")
                            .font(.caption2).multilineTextAlignment(.trailing).foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(14)
            }

            if let s = model.session, let c = s.current, !s.revealed {
                QuestionCard(card: c, session: s)
            }
        }
    }
}

struct LinkBanner: View {
    let a: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(a) ⟶ \(a + 1)").font(.caption.bold().monospacedDigit()).foregroundStyle(Color.glowOrange)
            Text(PM.elements[a].lien).font(.subheadline).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct Legend: View {
    let alch: Bool
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<10, id: \.self) { d in
                Text((alch ? "1" : "") + "\(d)x")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundStyle(PM.isDark(PM.dizHex[d]) ? Color.white : Color.black)
                    .frame(maxWidth: .infinity, minHeight: 20)
                    .background(PM.dizColor(d), in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}

struct Joystick: View {
    let onChange: (SIMD2<Float>) -> Void
    @State private var knob = CGSize.zero
    private let r: CGFloat = 52

    var body: some View {
        ZStack {
            Circle().fill(.black.opacity(0.35)).overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1.5))
            Circle().fill(.white.opacity(0.85)).frame(width: 40, height: 40).offset(knob)
        }
        .frame(width: r * 2, height: r * 2)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                var x = v.location.x - r, y = v.location.y - r
                let L = hypot(x, y)
                if L > r { x *= r / L; y *= r / L }
                knob = CGSize(width: x, height: y)
                onChange(SIMD2(Float(x / r), Float(y / r)))
            }
            .onEnded { _ in
                withAnimation(.spring(duration: 0.2)) { knob = .zero }
                onChange(.zero)
            })
        .accessibilityLabel("Joystick de déplacement")
    }
}
