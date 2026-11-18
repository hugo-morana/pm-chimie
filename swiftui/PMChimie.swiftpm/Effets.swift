import SwiftUI

// Effets d'interface. Les plus récents (iOS 18) ont un repli pour iOS 17.

// MARK: - Bouton qui s'enfonce avec un ressort

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .brightness(configuration.isPressed ? 0.12 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

// MARK: - Transition « zoom » d'un bouton vers une feuille (iOS 18)

extension View {
    @ViewBuilder
    func zoomSource(_ id: Int, in ns: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) { self.matchedTransitionSource(id: id, in: ns) } else { self }
    }

    @ViewBuilder
    func zoomDestination(_ id: Int, in ns: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) { self.navigationTransition(.zoom(sourceID: id, in: ns)) } else { self }
    }

    /// Carte qui grandit et s'éclaircit en entrant dans l'écran pendant le défilement.
    func scrollReveal() -> some View {
        scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.35)
                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                .blur(radius: phase.isIdentity ? 0 : 3)
                .offset(y: CGFloat(phase.value) * 14)
        }
    }

    /// Reflet lumineux qui balaie la vue de temps en temps.
    func shimmer(period: Double = 3.2, cornerRadius: CGFloat = 16) -> some View {
        overlay {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: w * 0.45)
                        .rotationEffect(.degrees(20))
                        .offset(x: CGFloat(t * 2.6 - 0.8) * w)
                        .blendMode(.plusLighter)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Fond en dégradé maillé animé (iOS 18)

struct LivingBackground: View {
    let accent: Color
    var body: some View {
        if #available(iOS 18.0, *) {
            MeshBackground(accent: accent)
        } else {
            LinearGradient(colors: [accent.opacity(0.35), Color(hex: 0x15171a)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

@available(iOS 18.0, *)
private struct MeshBackground: View {
    let accent: Color
    var body: some View {
        TimelineView(.animation) { tl in
            let t = Float(tl.date.timeIntervalSinceReferenceDate)
            let dark = Color(hex: 0x15171a), mid = Color(hex: 0x2a1f35)
            MeshGradient(
                width: 3, height: 3,
                points: [
                    SIMD2<Float>(0, 0), SIMD2<Float>(0.5 + 0.15 * sin(t * 0.6), 0), SIMD2<Float>(1, 0),
                    SIMD2<Float>(0, 0.5 + 0.12 * cos(t * 0.8)),
                    SIMD2<Float>(0.5 + 0.22 * sin(t * 0.7), 0.5 + 0.2 * cos(t * 0.5)),
                    SIMD2<Float>(1, 0.5 + 0.12 * sin(t * 0.9)),
                    SIMD2<Float>(0, 1), SIMD2<Float>(0.5 + 0.15 * cos(t * 0.4), 1), SIMD2<Float>(1, 1),
                ],
                colors: [
                    accent.opacity(0.55), mid, dark,
                    mid, accent.opacity(0.35), mid,
                    dark, mid, accent.opacity(0.25),
                ]
            )
        }
    }
}

// MARK: - Texte qui apparaît lettre par lettre (iOS 18, TextRenderer)

@available(iOS 18.0, *)
struct RevealRenderer: TextRenderer, Animatable {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        var slices: [Text.Layout.RunSlice] = []
        for line in layout {
            for run in line {
                for slice in run { slices.append(slice) }
            }
        }
        let count = max(slices.count, 1)
        for (i, slice) in slices.enumerated() {
            let start = Double(i) / Double(count) * 0.6
            let t = min(max((progress - start) / 0.4, 0), 1)
            var c = ctx
            c.opacity = t
            c.translateBy(x: 0, y: (1 - t) * 12)
            c.addFilter(.blur(radius: (1 - t) * 5))
            c.draw(slice)
        }
    }
}

/// Titre qui se dévoile en vague à son apparition.
struct RevealText: View {
    let text: String
    var font: Font = .title.bold()
    @State private var progress = 0.0
    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                Text(text).font(font).textRenderer(RevealRenderer(progress: progress))
            } else {
                Text(text).font(font).opacity(progress)
            }
        }
        .onAppear {
            progress = 0
            withAnimation(.easeOut(duration: 1.1)) { progress = 1 }
        }
    }
}

// MARK: - Nombre qui défile jusqu'à sa valeur

struct CountUp: View {
    let value: Int
    var font: Font = .title2.bold()
    @State private var shown = 0
    var body: some View {
        Text("\(shown)")
            .font(font.monospacedDigit())
            .contentTransition(.numericText(value: Double(shown)))
            .onAppear {
                shown = 0
                withAnimation(.snappy(duration: 0.9).delay(0.2)) { shown = value }
            }
    }
}
