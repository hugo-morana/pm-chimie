import Foundation
import simd

/// Géométrie du palais, reprise telle quelle de la version web (Three.js et SceneKit
/// partagent le même repère : y vers le haut, +z vers l'entrée des pièces).
enum Palace {
    struct Room {
        let id: Int
        let name: String
        let short: String
        let range: String
        let origin: SIMD3<Float>
        let alchemist: Bool
        let first: Int
        let last: Int
    }

    struct Basis {
        let c: SIMD3<Float>   // centre de la surface
        let n: SIMD3<Float>   // normale (vers l'intérieur de la pièce)
        let u: SIMD3<Float>   // « droite » du panneau
        let v: SIMD3<Float>   // « haut » du panneau
        func point(_ lx: Float, _ ly: Float, _ off: Float = 0) -> SIMD3<Float> {
            var p: SIMD3<Float> = c + u * lx
            p += v * ly
            p += n * off
            return p
        }
    }

    struct Slot {
        let n: Int
        let room: Int
        let d: Int
        let k: Int
        let pos: SIMD3<Float>
        let basis: Basis
    }

    struct View { var p: SIMD3<Float>; var t: SIMD3<Float>; var up: SIMD3<Float> = [0, 1, 0] }

    static let rooms: [Room] = [
        Room(id: 0, name: "Laboratoire moderne", short: "Labo moderne", range: "0 – 99",
             origin: [0, 0, 0], alchemist: false, first: 0, last: 99),
        Room(id: 1, name: "Laboratoire d'alchimiste", short: "Labo d'alchimiste", range: "100 – 199",
             origin: [24, 0, 0], alchemist: true, first: 100, last: 118),
    ]

    static let height: Float = 9.5
    static let poly: [SIMD2<Float>] = [[-8, 8], [-8, -3], [-4, -7], [4, -7], [8, -3], [8, 8]]
    static let walk: [SIMD2<Float>] = [[-6.85, 7.6], [-6.85, -2.4], [-3.45, -5.8], [3.45, -5.8], [6.85, -2.4], [6.85, 7.6]]

    private static func nrm(_ x: Float, _ y: Float, _ z: Float) -> SIMD3<Float> { simd_normalize(SIMD3<Float>(x, y, z)) }
    private static func v3(_ x: Float, _ y: Float, _ z: Float) -> SIMD3<Float> { SIMD3<Float>(x, y, z) }

    /// Les 10 surfaces : centre et normale, dans le repère de la pièce.
    static let surf: [(c: SIMD3<Float>, n: SIMD3<Float>)] = [
        (v3(-7.96, 4.05, 1.6), nrm(1, 0, 0)),
        (v3(-5.97, 4.05, -4.97), nrm(1, 0, 1)),
        (v3(0, 4.05, -6.96), nrm(0, 0, 1)),
        (v3(5.97, 4.05, -4.97), nrm(-1, 0, 1)),
        (v3(7.96, 4.05, 1.6), nrm(-1, 0, 0)),
        (v3(5.2, 0.42, 3.3), nrm(0, 1, 0.18)),
        (v3(0, 0.42, 3.3), nrm(0, 1, 0.18)),
        (v3(-5.2, 0.42, 3.3), nrm(0, 1, 0.18)),
        (v3(-3.75, 8.05, 1.1), nrm(0.3, -1, 0.62)),
        (v3(3.75, 8.05, 1.1), nrm(-0.3, -1, 0.62)),
    ]

    // Panneau : bords en coordonnées locales
    static let pl: Float = -1.65, pr: Float = 1.65, pb: Float = -2.3, pt: Float = 1.85
    static var panelW: Float { pr - pl }
    static var panelH: Float { pt - pb }
    static var panelCY: Float { (pt + pb) / 2 }
    static let colX: [Float] = [-0.9, 0, 0.9]
    static let rowY: [Float] = [0.25, -0.65, -1.55]
    /// Grille en serpentin : x1 x2 x3 / x6 x5 x4 / x7 x8 x9 ; x0 détaché au-dessus.
    static let cellRC: [Int: (Int, Int)] = [1: (0, 0), 2: (0, 1), 3: (0, 2), 6: (1, 0), 5: (1, 1), 4: (1, 2), 7: (2, 0), 8: (2, 1), 9: (2, 2)]

    static func cellLocal(_ k: Int) -> SIMD2<Float> {
        if k == 0 { return [-0.9, 1.27] }
        let rc = cellRC[k]!
        return [colX[rc.1], rowY[rc.0]]
    }

    static func basis(room: Int, d: Int) -> Basis {
        let s = surf[d]
        let n = s.n
        let u = simd_normalize(SIMD3<Float>(n.z, 0, -n.x))
        let v = simd_normalize(simd_cross(n, u))
        return Basis(c: s.c + rooms[room].origin, n: n, u: u, v: v)
    }

    /// Les 200 emplacements (0…199) ; seuls 0…118 portent une image.
    static let slots: [Slot] = {
        var out: [Slot] = []
        for r in 0..<2 {
            for d in 0..<10 {
                let b = basis(room: r, d: d)
                for k in 0..<10 {
                    let l = cellLocal(k)
                    out.append(Slot(n: r * 100 + d * 10 + k, room: r, d: d, k: k, pos: b.point(l.x, l.y, 0.012), basis: b))
                }
            }
        }
        return out
    }()

    static func panelCenter(room: Int, d: Int) -> SIMD3<Float> { basis(room: room, d: d).point(0, panelCY) }

    // MARK: Cadrages (aspect = largeur / hauteur de la zone visible, vfov en degrés)

    static func tangents(vfov: Float, aspect: Float) -> (tv: Float, th: Float) {
        let tv = tan(vfov * .pi / 360)
        return (tv, tv * aspect)
    }

    static func fitDist(w: Float, h: Float, vfov: Float, aspect: Float) -> Float {
        let t = tangents(vfov: vfov, aspect: aspect)
        return max((h / 2) / t.tv, (w / 2) / t.th)
    }

    static func overview(room: Int, vfov: Float, aspect: Float) -> View {
        let t = tangents(vfov: vfov, aspect: aspect)
        var zc = max(2 + 8.9 / t.th, 1.5 + 4.9 / t.tv)
        zc = min(max(zc, 14.2), 40)
        let h = 3.6 + zc * 0.08
        let o = rooms[room].origin
        return View(p: o + [0, h, zc], t: o + [0, 3.55, -1.2])
    }

    static func panelView(_ n: Int, vfov: Float, aspect: Float) -> View {
        let s = slots[n]
        let c = panelCenter(room: s.room, d: s.d)
        let dist = fitDist(w: 3.9, h: 4.8, vfov: vfov, aspect: aspect)
        return View(p: c + s.basis.n * dist, t: c, up: s.basis.v)
    }

    static func slotView(_ n: Int, vfov: Float, aspect: Float) -> View {
        let s = slots[n]
        let dist = fitDist(w: 1.15, h: 1.15, vfov: vfov, aspect: aspect)
        return View(p: s.pos + s.basis.n * dist, t: s.pos, up: s.basis.v)
    }

    // MARK: Visite libre

    static func inPoly(_ x: Float, _ z: Float, _ p: [SIMD2<Float>]) -> Bool {
        var ins = false
        var j = p.count - 1
        for i in 0..<p.count {
            let xi = p[i].x, zi = p[i].y, xj = p[j].x, zj = p[j].y
            if (zi > z) != (zj > z) && x < (xj - xi) * (z - zi) / (zj - zi) + xi { ins.toggle() }
            j = i
        }
        return ins
    }

    static func walkable(_ x: Float, _ z: Float) -> Bool {
        for r in rooms {
            let lx = x - r.origin.x, lz = z - r.origin.z
            if inPoly(lx, lz, walk) {
                if !r.alchemist && abs(lx) < 3.1 && lz > -4.2 && lz < -1.75 { return false }
                if r.alchemist && hypot(lx, lz + 3) < 2.5 { return false }
                return true
            }
            if abs(lx) < 1.9 && lz > 7.0 && lz < 9.0 { return true }
        }
        return z > 8.5 && z < 11.5 && x > -7.4 && x < rooms[1].origin.x + 7.4
    }

    static func roomAt(_ x: Float, _ z: Float) -> Int? {
        for r in rooms where inPoly(x - r.origin.x, z - r.origin.z, poly) { return r.id }
        return nil
    }
}
