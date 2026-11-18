import SceneKit
import UIKit
import simd

/// Ce que la scène doit montrer (calculé par le modèle).
struct SlotLook: Equatable {
    var current: Int = 0          // -1 : vue d'ensemble sans élément choisi
    var room: Int = 0
    var lvl: Int = 2
    var free = false
    var showChain = false
    var hideImg: Int? = nil       // emplacement masqué en noir
    var noDim = false
    var noHL = false
}

/// Possède la vue SceneKit : construction des deux laboratoires, caméra, gestes.
final class SceneController: NSObject, SCNSceneRendererDelegate {
    let view = SCNView(frame: .zero)
    let scene = SCNScene()
    private let cameraNode = SCNNode()

    // Rappels vers le modèle (toujours sur le fil principal)
    var onTapSlot: ((Int) -> Void)?
    var onSwipe: ((Int) -> Void)?
    var onFreeFocus: ((Int?, Int) -> Void)?   // (élément visé, pièce courante)

    private var slotNodes: [Int: SCNNode] = [:]
    private var floorNodes = Set<SCNNode>()
    private var overviewHidden: [SCNNode] = []
    private var chainLines: [Int: SCNNode] = [:]
    private let highlight = SCNNode()
    private let arrow = SCNNode()
    private let orb = SCNNode()
    private var wire: SCNNode?
    private var look = SlotLook()

    // État partagé avec le fil de rendu
    private let lock = NSLock()
    private var camPos = SIMD3<Float>(0, 4, 20)
    private var camTgt = SIMD3<Float>(0, 3, 0)
    private var camUp = SIMD3<Float>(0, 1, 0)
    private var tween: Tween?
    private var fs = FreeState()
    private var lastFocusTime: TimeInterval = 0
    private var lastFocus: Int? = nil
    private var lastRoom = 0

    struct FreeState {
        var on = false
        var yaw: Float = .pi
        var pitch: Float = 0
        var pos = SIMD3<Float>(0, 1.7, 6)
        var joy = SIMD2<Float>(0, 0)
        var target: FreeTarget? = nil
        var fov: Float = 0          // angle de vue (zoom à deux doigts) ; 0 = valeur par défaut
    }

    struct FreeTarget { var x: Float; var z: Float; var look: SIMD3<Float>? }

    struct Tween {
        enum Kind { case arc, walk }
        var kind: Kind
        var fromP: SIMD3<Float>, fromT: SIMD3<Float>, fromUp: SIMD3<Float>
        var to: Palace.View
        var ctrl: SIMD3<Float>
        var path: Path?
        var t0: TimeInterval
        var dur: TimeInterval
        var onDone: (() -> Void)?
    }

    /// Courbe échantillonnée, paramétrée par la longueur.
    struct Path {
        var pts: [SIMD3<Float>] = []
        var cum: [Float] = []
        var length: Float { cum.last ?? 0 }

        init(through ctrl: [SIMD3<Float>]) {
            // Catmull-Rom uniforme, 24 échantillons par segment
            let p = [ctrl[0]] + ctrl + [ctrl[ctrl.count - 1]]
            for i in 1..<(p.count - 2) {
                for s in 0..<24 {
                    let t = Float(s) / 24
                    let t2 = t * t, t3 = t2 * t
                    let p0: SIMD3<Float> = p[i - 1], p1: SIMD3<Float> = p[i], p2: SIMD3<Float> = p[i + 1], p3: SIMD3<Float> = p[i + 2]
                    let a: SIMD3<Float> = 2 * p1
                    let b: SIMD3<Float> = (p2 - p0) * t
                    var c: SIMD3<Float> = 2 * p0 - 5 * p1
                    c += 4 * p2 - p3
                    var d: SIMD3<Float> = 3 * p1 - p0
                    d += p3 - 3 * p2
                    let sum: SIMD3<Float> = a + b + c * t2 + d * t3
                    pts.append(0.5 * sum)
                }
            }
            pts.append(ctrl[ctrl.count - 1])
            var acc: Float = 0
            cum = [0]
            for i in 1..<pts.count { acc += simd_distance(pts[i], pts[i - 1]); cum.append(acc) }
        }

        func point(at u: Float) -> SIMD3<Float> {
            guard pts.count > 1, length > 0 else { return pts.first ?? .zero }
            let target = min(max(u, 0), 1) * length
            var lo = 0, hi = cum.count - 1
            while hi - lo > 1 { let m = (lo + hi) / 2; if cum[m] < target { lo = m } else { hi = m } }
            let seg = cum[hi] - cum[lo]
            let f = seg > 0 ? (target - cum[lo]) / seg : 0
            return simd_mix(pts[lo], pts[hi], SIMD3<Float>(repeating: f))
        }
    }

    // MARK: - Construction

    override init() {
        super.init()
        view.scene = scene
        view.backgroundColor = UIColor(hex: 0x1b1e22)
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.delegate = self
        view.isPlaying = true
        view.rendersContinuously = true
        scene.background.contents = UIColor(hex: 0x1b1e22)

        let cam = SCNCamera()
        cam.zNear = 0.05
        cam.zFar = 200
        cam.fieldOfView = 60
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode

        addLights()
        for r in Palace.rooms { buildRoom(r) }
        buildCorridor()
        buildMarkers()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        view.addGestureRecognizer(pinch)
    }

    private func addLights() {
        let amb = SCNNode(); amb.light = SCNLight(); amb.light!.type = .ambient
        amb.light!.color = UIColor(white: 0.62, alpha: 1)
        scene.rootNode.addChildNode(amb)
        let sun = SCNNode(); sun.light = SCNLight(); sun.light!.type = .directional
        sun.light!.color = UIColor(white: 0.55, alpha: 1)
        sun.simdPosition = [8, 20, 14]; sun.simdLook(at: [0, 0, 0], up: [0, 1, 0], localFront: [0, 0, -1])
        scene.rootNode.addChildNode(sun)
        for r in Palace.rooms {
            let l = SCNNode(); l.light = SCNLight(); l.light!.type = .omni
            l.light!.color = UIColor(white: 0.45, alpha: 1)
            l.light!.attenuationStartDistance = 6; l.light!.attenuationEndDistance = 30
            l.simdPosition = r.origin + [0, 7.5, 1]
            scene.rootNode.addChildNode(l)
        }
    }

    // Matériaux
    private static func phong(_ hex: UInt32, shininess: CGFloat = 0.5) -> SCNMaterial {
        let m = SCNMaterial(); m.lightingModel = .phong
        m.diffuse.contents = UIColor(hex: hex); m.specular.contents = UIColor(white: 0.5, alpha: 1); m.shininess = shininess
        return m
    }
    private static func lambert(_ contents: Any) -> SCNMaterial {
        let m = SCNMaterial(); m.lightingModel = .lambert; m.diffuse.contents = contents; return m
    }
    private static func constant(_ contents: Any) -> SCNMaterial {
        let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = contents; return m
    }
    private static func tiled(_ image: UIImage, _ sx: Float, _ sy: Float, lit: Bool = true) -> SCNMaterial {
        let m = lit ? lambert(image) : constant(image)
        m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(sx, sy, 1)
        return m
    }

    private let steel = SceneController.phong(0xb9c0c6, shininess: 0.6)
    private let steelDark = SceneController.phong(0x7d858c, shininess: 0.4)
    private let wood = SceneController.lambert(UIColor(hex: 0x7a4825))
    private let woodDark = SceneController.lambert(UIColor(hex: 0x4d2b14))
    private let copper = SceneController.phong(0xc06a35, shininess: 0.8)
    private let brass = SceneController.phong(0xc9a043, shininess: 0.7)
    private let lamp = SceneController.constant(UIColor(hex: 0xfffbe8))
    private let glow = SceneController.constant(UIColor(hex: 0xffd9a0))
    private lazy var glass: [SCNMaterial] = ([0x3ba3ff, 0xff4d4d, 0x4dd27a, 0xffb43b, 0xb66bff, 0x37d6d0] as [UInt32]).map { hex in
        let m = Self.phong(hex, shininess: 0.9); m.transparency = 0.62; m.blendMode = .alpha; return m
    }

    @discardableResult
    private func box(_ p: SCNNode, _ w: Float, _ h: Float, _ d: Float, _ m: SCNMaterial,
                     _ x: Float, _ y: Float, _ z: Float, ry: Float = 0) -> SCNNode {
        let g = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0)
        g.materials = [m]
        let n = SCNNode(geometry: g); n.simdPosition = [x, y, z]; n.simdEulerAngles = [0, ry, 0]
        p.addChildNode(n); return n
    }

    @discardableResult
    private func cyl(_ p: SCNNode, _ rt: Float, _ rb: Float, _ h: Float, _ m: SCNMaterial,
                     _ x: Float, _ y: Float, _ z: Float, seg: Int = 16) -> SCNNode {
        let g: SCNGeometry
        if rt == rb {
            let c = SCNCylinder(radius: CGFloat(rt), height: CGFloat(h)); c.radialSegmentCount = seg; g = c
        } else {
            let c = SCNCone(topRadius: CGFloat(rt), bottomRadius: CGFloat(rb), height: CGFloat(h)); c.radialSegmentCount = seg; g = c
        }
        g.materials = [m]
        let n = SCNNode(geometry: g); n.simdPosition = [x, y, z]
        p.addChildNode(n); return n
    }

    private func sphere(_ p: SCNNode, _ r: Float, _ m: SCNMaterial, _ pos: SIMD3<Float>) {
        let g = SCNSphere(radius: CGFloat(r)); g.segmentCount = 14; g.materials = [m]
        let n = SCNNode(geometry: g); n.simdPosition = pos; p.addChildNode(n)
    }

    private func plane(_ w: Float, _ h: Float, _ m: SCNMaterial) -> SCNNode {
        let g = SCNPlane(width: CGFloat(w), height: CGFloat(h)); g.materials = [m]
        return SCNNode(geometry: g)
    }

    /// Mur vertical de a à b, face visible tournée vers l'intérieur (à gauche de a→b).
    @discardableResult
    private func wall(_ p: SCNNode, _ ax: Float, _ az: Float, _ bx: Float, _ bz: Float,
                      _ y0: Float, _ y1: Float, _ img: UIImage, unit: Float) -> SCNNode {
        let dx = bx - ax, dz = bz - az, L = hypot(dx, dz), h = y1 - y0
        let n = plane(L, h, Self.tiled(img, L / unit, h / unit))
        let nx = -dz / L, nz = dx / L
        n.simdPosition = [(ax + bx) / 2, (y0 + y1) / 2, (az + bz) / 2]
        n.simdEulerAngles = [0, atan2(nx, nz), 0]
        p.addChildNode(n); return n
    }

    private func orient(_ node: SCNNode, _ b: Palace.Basis) {
        node.simdOrientation = simd_quatf(simd_float3x3(columns: (b.u, b.v, b.n)))
    }

    private func buildRoom(_ R: Palace.Room) {
        let m = !R.alchemist
        let G = SCNNode(); scene.rootNode.addChildNode(G)
        let LG = SCNNode(); LG.simdPosition = R.origin; G.addChildNode(LG)
        let H = Palace.height

        // sol et plafond : rectangles couvrant le polygone (les coins coupés restent derrière les murs)
        let fl = plane(16, 15, Self.tiled(m ? Tex.mFloor : Tex.aFloor, 16 / 2.4, 15 / 2.4))
        fl.simdEulerAngles = [-.pi / 2, 0, 0]; fl.simdPosition = [0, 0, 0.5]
        LG.addChildNode(fl); floorNodes.insert(fl)
        let ce = plane(16, 15, Self.tiled(m ? Tex.mCeil : Tex.aCeil, 4, 3.75, lit: false))
        ce.simdEulerAngles = [.pi / 2, 0, 0]; ce.simdPosition = [0, H, 0.5]
        LG.addChildNode(ce)

        let wimg = m ? Tex.mWall : Tex.aWall, unit: Float = m ? 3 : 3.2
        let P = Palace.poly
        for i in 0..<(P.count - 1) { wall(LG, P[i].x, P[i].y, P[i + 1].x, P[i + 1].y, 0, H, wimg, unit: unit) }
        // mur d'entrée (z = 8) avec une porte de 4,4 × 3,2
        wall(LG, 8, 8, 2.2, 8, 0, H, wimg, unit: unit)
        wall(LG, -2.2, 8, -8, 8, 0, H, wimg, unit: unit)
        wall(LG, 2.2, 8, -2.2, 8, 3.2, H, wimg, unit: unit)
        let jamb = m ? steelDark : woodDark
        overviewHidden += [box(LG, 0.25, 3.4, 0.5, jamb, -2.3, 1.7, 8), box(LG, 0.25, 3.4, 0.5, jamb, 2.3, 1.7, 8),
                           box(LG, 4.85, 0.3, 0.5, jamb, 0, 3.35, 8)]

        // paillasses le long des murs
        let body = m ? steel : wood, top = m ? steelDark : woodDark
        let segs: [(SIMD2<Float>, SIMD2<Float>)] = [([-8, 7.4], [-8, -3]), ([-8, -3], [-4, -7]), ([-4, -7], [4, -7]),
                                                     ([4, -7], [8, -3]), ([8, -3], [8, 7.4])]
        var rr = Tex.Rnd(m ? 41 : 43)
        for (a, b) in segs {
            let dx = b.x - a.x, dz = b.y - a.y, L = hypot(dx, dz)
            let nx = -dz / L, nz = dx / L
            let cx = (a.x + b.x) / 2 + nx * 0.45, cz = (a.y + b.y) / 2 + nz * 0.45
            let ry = atan2(nx, nz)
            box(LG, L - 0.3, 0.9, 0.85, body, cx, 0.45, cz, ry: ry)
            box(LG, L - 0.2, 0.06, 0.95, top, cx, 0.93, cz, ry: ry)
            let nd = Int(L / 1.2)
            for k in 0..<nd {
                let t = (Float(k) + 0.5) / Float(nd) - 0.5
                box(LG, 0.9, 0.5, 0.02, top, cx + dx / L * t * (L - 0.6) + nx * 0.43, 0.5, cz + dz / L * t * (L - 0.6) + nz * 0.43, ry: ry)
            }
            let nb = Int(L / 0.7)
            for k in 0..<nb {
                if rr.next() < 0.35 { continue }
                let t = (Float(k) + 0.5) / Float(nb) - 0.5
                let px = cx + dx / L * t * (L - 0.6) - nx * 0.15, pz = cz + dz / L * t * (L - 0.6) - nz * 0.15
                let gm = glass[Int(rr.next() * CGFloat(glass.count)) % glass.count]
                if rr.next() < 0.5 {
                    cyl(LG, 0.05, 0.16, 0.32, gm, px, 1.12, pz, seg: 12); cyl(LG, 0.045, 0.05, 0.14, gm, px, 1.33, pz, seg: 10)
                } else {
                    cyl(LG, 0.07, 0.07, 0.36 + Float(rr.next()) * 0.2, gm, px, 1.16, pz, seg: 12)
                }
            }
        }

        if m {
            box(LG, 5.4, 0.95, 1.7, steel, 0, 0.48, -3); box(LG, 5.6, 0.07, 1.9, steelDark, 0, 0.98, -3)
            for k in 0..<10 { cyl(LG, 0.045, 0.045, 0.42, glass[k % 6], -1.6 + Float(k) * 0.36, 1.22, -3.2, seg: 10) }
            box(LG, 3.8, 0.05, 0.18, steelDark, 0, 1.05, -3.2)
            cyl(LG, 0.03, 0.03, 1.4, steel, 1.9, 1.7, -2.7, seg: 8); cyl(LG, 0.2, 0.2, 0.04, steel, 1.9, 2.4, -2.7)
            cyl(LG, 0.25, 0.25, 0.06, steelDark, 0, 0.7, -1.7); cyl(LG, 0.04, 0.04, 0.7, steel, 0, 0.35, -1.7, seg: 8)
            for sx: Float in [-1, 1] {
                cyl(LG, 0.3, 0.3, H, steel, sx * 7.2, H / 2, -3.4)
                cyl(LG, 0.35, 0.9, 0.7, steel, sx * 7.0, 3.0, -3.6, seg: 4)
            }
            for z: Float in [-5, -1.5, 2.5, 6] { box(LG, 0.25, 0.05, 2.6, lamp, 0, H - 0.05, z) }
        } else {
            let rug = plane(6.5, 5, Self.lambert(Tex.rug)); rug.simdEulerAngles = [-.pi / 2, 0, 0]; rug.simdPosition = [0, 0.01, -2.8]
            LG.addChildNode(rug)
            cyl(LG, 2.0, 2.0, 0.12, wood, 0, 1.0, -3, seg: 40); cyl(LG, 0.35, 0.7, 0.95, woodDark, 0, 0.47, -3)
            cyl(LG, 0.9, 0.9, 0.08, woodDark, 0, 0.04, -3, seg: 24)
            cyl(LG, 0.03, 0.03, 0.6, brass, 0, 1.36, -3.2, seg: 8); box(LG, 0.9, 0.03, 0.03, brass, 0, 1.66, -3.2)
            cyl(LG, 0.16, 0.16, 0.02, brass, -0.45, 1.5, -3.2); cyl(LG, 0.16, 0.16, 0.02, brass, 0.45, 1.5, -3.2)
            for k in 0..<4 {
                let a = Float(k) / 4 * 2 * .pi + 0.5
                cyl(LG, 0.05, 0.2, 0.36, glass[k], cos(a) * 1.3, 1.24, -3 + sin(a) * 1.3, seg: 12)
            }
            for a: Float in [0.4, 2.0, 3.6, 5.1] {
                cyl(LG, 0.26, 0.26, 0.07, woodDark, cos(a) * 2.6, 0.72, -3 + sin(a) * 2.6, seg: 14)
                cyl(LG, 0.05, 0.05, 0.7, woodDark, cos(a) * 2.6, 0.36, -3 + sin(a) * 2.6, seg: 8)
            }
            for sx: Float in [-1, 1] {
                cyl(LG, 0.28, 0.32, H, copper, sx * 7.25, H / 2, -3.3)
                sphere(LG, 0.42, copper, [sx * 6.9, 1.45, -3.8])
                cyl(LG, 0.05, 0.2, 0.6, copper, sx * 6.9, 2.1, -3.8, seg: 12)
            }
            let torus = SCNTorus(ringRadius: 1.2, pipeRadius: 0.05); torus.materials = [brass]
            let ring = SCNNode(geometry: torus); ring.simdPosition = [0, 7.2, -1.2]; LG.addChildNode(ring)
            cyl(LG, 0.03, 0.03, 2.3, brass, 0, 8.35, -1.2, seg: 6)
            for k in 0..<8 {
                let a = Float(k) / 8 * 2 * .pi
                sphere(LG, 0.11, glow, [cos(a) * 1.2, 7.35, -1.2 + sin(a) * 1.2])
            }
            var bk = Tex.Rnd(5)
            let bookCols: [UInt32] = [0x7a1f1f, 0x23446b, 0x2f5a32, 0x5b3b1c]
            for k in 0..<16 {
                box(LG, 0.22, 0.3 + Float(bk.next()) * 0.12, 0.12, Self.lambert(UIColor(hex: bookCols[k % 4])), -7.4, 1.12, 6.5 - Float(k) * 0.16)
            }
        }

        // panneaux des dizaines et emplacements
        let W = Palace.panelW, Hh = Palace.panelH, cy = Palace.panelCY
        for d in 0..<10 {
            let B = Palace.basis(room: R.id, d: d)
            let frame = box(G, W + 0.22, Hh + 0.22, 0.08, m ? steelDark : brass, 0, 0, 0)
            frame.simdPosition = B.point(0, cy, -0.045); orient(frame, B)
            let pm = plane(W, Hh, Self.constant(Tex.panel(alchemist: R.alchemist, d: d)))
            pm.simdPosition = B.point(0, cy, 0); orient(pm, B); G.addChildNode(pm)
            for k in 0..<10 {
                let n = R.id * 100 + d * 10 + k
                guard n <= PM.maxN else { continue }
                let l = Palace.cellLocal(k)
                let mat = Self.constant(ImageStore.shared.thumb(n))
                let im = plane(0.6, 0.6, mat)
                im.simdPosition = B.point(l.x + 0.12, l.y - 0.12, 0.014); orient(im, B)
                im.name = "slot\(n)"
                G.addChildNode(im)
                slotNodes[n] = im
            }
        }

        // enseigne côté couloir
        let sign = plane(5.2, 0.95, Self.constant(Tex.sign(R)))
        sign.simdPosition = [R.origin.x, 3.75, 8.02]
        scene.rootNode.addChildNode(sign); overviewHidden.append(sign)
    }

    private func buildCorridor() {
        let G = SCNNode(); scene.rootNode.addChildNode(G)
        let x0: Float = -8, x1 = Palace.rooms[1].origin.x + 8, z0: Float = 8, z1: Float = 12, hc: Float = 4.2
        let fl = plane(x1 - x0, z1 - z0, Self.tiled(Tex.cFloor, (x1 - x0) / 2, (z1 - z0) / 2))
        fl.simdEulerAngles = [-.pi / 2, 0, 0]; fl.simdPosition = [(x0 + x1) / 2, 0.005, (z0 + z1) / 2]
        G.addChildNode(fl); floorNodes.insert(fl)
        wall(G, x1, z1, x0, z1, 0, hc, Tex.cWall, unit: 2.5)
        wall(G, x0, z1, x0, z0, 0, hc, Tex.cWall, unit: 2.5)
        wall(G, x1, z0, x1, z1, 0, hc, Tex.cWall, unit: 2.5)
        let ce = plane(x1 - x0, z1 - z0, Self.lambert(UIColor(hex: 0xd8d4cc)))
        ce.simdEulerAngles = [.pi / 2, 0, 0]; ce.simdPosition = [(x0 + x1) / 2, hc, (z0 + z1) / 2]
        G.addChildNode(ce); overviewHidden.append(ce)
        // faces côté couloir des murs d'entrée
        let doors = Palace.rooms.map { $0.origin.x }
        var xs = x0
        var pieces: [(Float, Float)] = []
        for dx in doors { pieces.append((xs, dx - 2.2)); xs = dx + 2.2 }
        pieces.append((xs, x1))
        for (a, b) in pieces { overviewHidden.append(wall(G, a, z0 + 0.01, b, z0 + 0.01, 0, hc, Tex.cWall, unit: 2.5)) }
        for dx in doors { overviewHidden.append(wall(G, dx - 2.2, z0 + 0.01, dx + 2.2, z0 + 0.01, 3.2, hc, Tex.cWall, unit: 2.5)) }
        var x = x0 + 3
        while x < x1 { overviewHidden.append(box(G, 1.6, 0.05, 0.25, lamp, x, hc - 0.04, 10)); x += 5 }
    }

    private func buildMarkers() {
        let hm = Self.constant(UIColor(hex: 0xffb347))
        for (w, h, x, y) in [(Float(0.96), Float(0.06), Float(0), Float(0.45)), (0.96, 0.06, 0, -0.45), (0.06, 0.96, 0.45, 0), (0.06, 0.96, -0.45, 0)] {
            box(highlight, w, h, 0.04, hm, x, y, 0.03)
        }
        scene.rootNode.addChildNode(highlight)

        let cone = SCNCone(topRadius: 0, bottomRadius: 0.28, height: 0.7); cone.materials = [hm]
        let tip = SCNNode(geometry: cone)
        tip.simdEulerAngles = [.pi, 0, 0]   // pointe vers le bas du repère local
        arrow.addChildNode(tip)
        tip.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.25, z: 0, duration: 0.5), .moveBy(x: 0, y: -0.25, z: 0, duration: 0.5)])))
        arrow.isHidden = true
        scene.rootNode.addChildNode(arrow)

        let og = SCNSphere(radius: 0.12); og.materials = [Self.constant(UIColor(hex: 0xfff1c9))]
        orb.geometry = og; orb.isHidden = true
        scene.rootNode.addChildNode(orb)
    }

    // MARK: - Fil des liens

    private func slotTip(_ n: Int) -> SIMD3<Float> { let s = Palace.slots[n]; return s.pos + s.basis.n * 0.12 }

    private func chainPoints(_ a: Int, _ b: Int) -> [SIMD3<Float>] {
        let A = Palace.slots[a], B = Palace.slots[b]
        let pa = slotTip(a), pb = slotTip(b)
        if A.room == B.room {
            let c = Palace.rooms[A.room].origin + [0, 3.8, 1]
            let mid = (pa + pb) / 2
            let f = min(max(simd_distance(pa, pb) / 14, 0.15), 0.55)
            return Path(through: [pa, simd_mix(mid, c, SIMD3(repeating: f)), pb]).pts
        }
        let RA = Palace.rooms[A.room].origin, RB = Palace.rooms[B.room].origin
        let w1: SIMD3<Float> = RA + SIMD3<Float>(0, 2.6, 4)
        let w2: SIMD3<Float> = RA + SIMD3<Float>(0, 1.9, 9.8)
        let w3: SIMD3<Float> = RB + SIMD3<Float>(0, 1.9, 9.8)
        let w4: SIMD3<Float> = RB + SIMD3<Float>(0, 2.6, 4)
        return Path(through: [pa, w1, w2, w3, w4, pb]).pts
    }

    private func tube(_ pts: [SIMD3<Float>], radius: Float, _ m: SCNMaterial) -> [SCNNode] {
        var out: [SCNNode] = []
        for i in 1..<pts.count {
            let p = pts[i - 1], q = pts[i], L = simd_distance(p, q)
            guard L > 1e-4 else { continue }
            let c = SCNCylinder(radius: CGFloat(radius), height: CGFloat(L)); c.radialSegmentCount = 6; c.materials = [m]
            let n = SCNNode(geometry: c)
            n.simdPosition = (p + q) / 2
            n.simdOrientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(q - p))
            out.append(n)
        }
        return out
    }

    /// Anime le fil de a vers b (avec la boule lumineuse), puis l'efface.
    func showWire(from a: Int, to b: Int, duration: TimeInterval) {
        wire?.removeFromParentNode(); wire = nil
        guard (0...PM.maxN).contains(a), (0...PM.maxN).contains(b) else { return }
        let same = Palace.slots[a].room == Palace.slots[b].room
        let pts = chainPoints(a, b)
        let mat = Self.constant(UIColor(hex: 0xffc070))
        let segs = tube(pts, radius: same ? 0.035 : 0.014, mat)
        let w = SCNNode()
        for s in segs { s.isHidden = true; w.addChildNode(s) }
        scene.rootNode.addChildNode(w)
        wire = w
        let exact = pts
        let orb = self.orb
        let reveal = SCNAction.customAction(duration: duration) { node, elapsed in
            let e = Float(elapsed / CGFloat(duration))
            let shown = Int(Float(segs.count) * e)
            for (i, s) in segs.enumerated() where i < shown { s.isHidden = false }
            let u = Self.ease(e)
            let idx = min(Int(u * Float(exact.count - 1)), exact.count - 1)
            orb.simdPosition = exact[idx]
            orb.isHidden = e >= 1
            _ = node
        }
        w.runAction(.sequence([reveal, .run { _ in
            orb.isHidden = true
            for s in segs { s.isHidden = false }
        }, .wait(duration: 3.2), .fadeOut(duration: 0.6), .removeFromParentNode()]))
    }

    private func chainLine(_ rid: Int) -> SCNNode {
        if let c = chainLines[rid] { return c }
        let R = Palace.rooms[rid]
        let g = SCNNode()
        let mat = Self.constant(UIColor(hex: 0xffc070)); mat.transparency = 0.75; mat.blendMode = .alpha
        let dot = Self.constant(UIColor(hex: 0xfff1c9))
        for n in R.first...R.last {
            if n < R.last { for s in tube(chainPoints(n, n + 1), radius: 0.022, mat) { g.addChildNode(s) } }
            sphere(g, 0.06, dot, slotTip(n))
        }
        g.isHidden = true
        scene.rootNode.addChildNode(g)
        chainLines[rid] = g
        return g
    }

    // MARK: - Apparence des emplacements

    func apply(_ L: SlotLook) {
        look = L
        let dimRoom = L.current >= 0 ? Palace.slots[L.current].room : -1
        for (n, node) in slotNodes {
            guard let m = node.geometry?.firstMaterial else { continue }
            if L.hideImg == n {
                m.diffuse.contents = UIColor.black
            } else {
                if !(m.diffuse.contents is UIImage) { m.diffuse.contents = ImageStore.shared.thumb(n) }
                let dim = !L.free && L.lvl == 0 && L.current >= 0 && Palace.slots[n].room == dimRoom && n != L.current && !L.noDim
                m.multiply.contents = dim ? UIColor(white: 0.36, alpha: 1) : UIColor.white
            }
        }
        let showHL = L.current >= 0 && !L.noHL
        highlight.isHidden = !showHL
        if showHL {
            let s = Palace.slots[L.current]
            highlight.simdPosition = s.pos; orient(highlight, s.basis)
            arrow.simdPosition = s.pos + s.basis.n * 1.0
            arrow.simdOrientation = simd_quatf(from: [0, -1, 0], to: -s.basis.n)
        }
        arrow.isHidden = !(showHL && L.lvl == 0 && !L.free)
        for (_, c) in chainLines { c.isHidden = true }
        if L.showChain && !L.free { chainLine(L.room).isHidden = false }
    }

    func setOverviewHidden(_ hide: Bool) { for n in overviewHidden { n.isHidden = hide } }

    // MARK: - Caméra

    var aspect: Float {
        let b = view.bounds
        return b.height > 0 ? Float(b.width / b.height) : 0.6
    }
    var vfov: Float { aspect < 1 ? 70 : 56 }

    func cameraView(for n: Int, lvl: Int, room: Int) -> Palace.View {
        let a = aspect, f = vfov
        if n < 0 || lvl == 0 { return Palace.overview(room: n < 0 ? room : Palace.slots[n].room, vfov: f, aspect: a) }
        return lvl == 1 ? Palace.panelView(n, vfov: f, aspect: a) : Palace.slotView(n, vfov: f, aspect: a)
    }

    static func ease(_ t: Float) -> Float { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }

    /// Va vers une vue ; un changement de pièce passe par le couloir.
    @discardableResult
    func move(to v: Palace.View, fromRoom: Int, toRoom: Int, duration: TimeInterval, instant: Bool = false,
              onDone: (() -> Void)? = nil) -> TimeInterval {
        lock.lock(); defer { lock.unlock() }
        fs.on = false
        cameraNode.camera?.fieldOfView = CGFloat(vfov)
        if instant {
            tween = nil; camPos = v.p; camTgt = v.t; camUp = v.up
            DispatchQueue.main.async { onDone?() }
            return 0
        }
        let now = CACurrentMediaTime()
        if fromRoom != toRoom {
            let A = Palace.rooms[fromRoom].origin, B = Palace.rooms[toRoom].origin, y: Float = 1.7
            let w1: SIMD3<Float> = A + SIMD3<Float>(0, y + 0.6, 4.5)
            let w2: SIMD3<Float> = A + SIMD3<Float>(0, y, 9.6)
            let w3: SIMD3<Float> = B + SIMD3<Float>(0, y, 10.4)
            let w4: SIMD3<Float> = B + SIMD3<Float>(0, y, 4.5)
            let path = Path(through: [camPos, w1, w2, w3, w4, v.p])
            let dur = max(2.6, Double(path.length) / 9)
            tween = Tween(kind: .walk, fromP: camPos, fromT: camTgt, fromUp: camUp, to: v, ctrl: .zero, path: path,
                          t0: now, dur: dur, onDone: onDone)
            return dur
        }
        let obs = Palace.rooms[toRoom].origin + [0, 3.4, 5.5]
        let mid = (camPos + v.p) / 2
        tween = Tween(kind: .arc, fromP: camPos, fromT: camTgt, fromUp: camUp, to: v, ctrl: simd_mix(mid, obs, SIMD3(repeating: 0.45)),
                      path: nil, t0: now, dur: duration, onDone: onDone)
        return duration
    }

    /// Termine tout de suite le déplacement en cours.
    func finishTween() {
        lock.lock()
        guard let t = tween else { lock.unlock(); return }
        tween = nil; camPos = t.to.p; camTgt = t.to.t; camUp = t.to.up
        lock.unlock()
        t.onDone?()
    }

    // MARK: Visite libre

    func enterFree(at p: SIMD3<Float>? = nil, yaw: Float? = nil) {
        lock.lock(); defer { lock.unlock() }
        tween = nil
        cameraNode.camera?.fieldOfView = CGFloat(vfov)
        if let p { fs.pos = [p.x, 1.7, p.z] } else {
            // depuis la caméra actuelle, ramenée dans une zone praticable
            var q = SIMD3<Float>(camPos.x, 1.7, camPos.z)
            let room = Palace.roomAt(q.x, q.z) ?? lastRoom
            let home = Palace.rooms[room].origin + [0, 1.7, 6.2]
            var i = 0
            while !Palace.walkable(q.x, q.z) && i < 40 { q = simd_mix(q, home, SIMD3(repeating: 0.2)); i += 1 }
            if !Palace.walkable(q.x, q.z) { q = home }
            fs.pos = q
        }
        if let yaw { fs.yaw = yaw } else {
            let d = camTgt - camPos
            fs.yaw = atan2(-d.x, -d.z)
        }
        fs.pitch = 0
        fs.target = nil
        fs.fov = vfov
        fs.on = true
    }

    func setJoystick(_ v: SIMD2<Float>) { lock.lock(); fs.joy = v; lock.unlock() }

    // MARK: Gestes

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        let p = g.location(in: view)
        let hits = view.hitTest(p, options: [.searchMode: SCNHitTestSearchMode.all.rawValue, .ignoreHiddenNodes: true])
        lock.lock(); let isFree = fs.on; lock.unlock()
        for h in hits {
            if let name = h.node.name, name.hasPrefix("slot"), let n = Int(name.dropFirst(4)) {
                if isFree {
                    let s = Palace.slots[n]
                    var q = s.pos + s.basis.n * 2.6; q.y = 1.7
                    let home = Palace.rooms[s.room].origin + [0, 1.7, 3]
                    var i = 0
                    while !Palace.walkable(q.x, q.z) && i < 20 { q = simd_mix(q, home, SIMD3(repeating: 0.2)); i += 1 }
                    lock.lock(); fs.target = FreeTarget(x: q.x, z: q.z, look: s.pos); lock.unlock()
                }
                onTapSlot?(n)
                return
            }
            if isFree && floorNodes.contains(h.node) {
                let w = h.worldCoordinates
                var q = SIMD3<Float>(Float(w.x), 1.7, Float(w.z))
                lock.lock()
                let back = simd_normalize(SIMD3<Float>(fs.pos.x - q.x, 0, fs.pos.z - q.z)) * 0.25
                var i = 0
                while !Palace.walkable(q.x, q.z) && i < 30 { q += back; i += 1 }
                fs.target = FreeTarget(x: q.x, z: q.z, look: nil)
                lock.unlock()
                return
            }
        }
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        lock.lock(); let isFree = fs.on; lock.unlock()
        if isFree {
            let d = g.translation(in: view)
            g.setTranslation(.zero, in: view)
            lock.lock()
            // plus on zoome, plus le regard tourne lentement
            let k: Float = 0.005 * (fs.fov > 0 ? fs.fov / vfov : 1)
            fs.yaw += Float(d.x) * k
            fs.pitch = min(max(fs.pitch + Float(d.y) * k, -1.35), 1.35)
            fs.target = nil
            lock.unlock()
        } else if g.state == .ended {
            let t = g.translation(in: view), v = g.velocity(in: view)
            if (abs(t.x) > 50 && abs(t.x) > abs(t.y) * 1.3) || (abs(v.x) > 600 && abs(v.x) > abs(v.y)) {
                onSwipe?(t.x < 0 ? 1 : -1)
            }
        }
    }

    /// Visite libre : pincer pour zoomer ou dézoomer (angle de vue de la caméra).
    private var pinchStartFov: Float = 0

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        lock.lock(); defer { lock.unlock() }
        guard fs.on else { return }
        if fs.fov <= 0 { fs.fov = vfov }
        if g.state == .began { pinchStartFov = fs.fov }
        guard pinchStartFov > 0, g.scale > 0 else { return }
        fs.fov = min(max(pinchStartFov / Float(g.scale), 12), vfov + 25)
    }

    // MARK: - Boucle de rendu

    private var lastTime: TimeInterval = 0

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt = Float(min(0.05, lastTime == 0 ? 0 : time - lastTime)); lastTime = time
        lock.lock()
        var done: (() -> Void)? = nil
        if fs.on {
            stepFree(dt)
        } else if var tw = tween {
            let now = CACurrentMediaTime()
            let t = Float(min(max((now - tw.t0) / tw.dur, 0), 1))
            let e = Self.ease(t)
            if tw.kind == .arc {
                let u = 1 - e
                let k0: Float = u * u, k1: Float = 2 * u * e, k2: Float = e * e
                var cp: SIMD3<Float> = tw.fromP * k0
                cp += tw.ctrl * k1
                cp += tw.to.p * k2
                camPos = cp
                camTgt = simd_mix(tw.fromT, tw.to.t, SIMD3(repeating: e))
                camUp = simd_normalize(simd_mix(tw.fromUp, tw.to.up, SIMD3(repeating: e)))
            } else if let path = tw.path {
                let p = path.point(at: e)
                camPos = p
                var tan = path.point(at: min(e + 0.02, 1)) - p; tan.y = 0
                let ahead: SIMD3<Float> = simd_length(tan) > 1e-4 ? p + simd_normalize(tan) * 6 : tw.to.t
                let wIn = min(max(e / 0.12, 0), 1), wOut = min(max((e - 0.75) / 0.25, 0), 1)
                var tg = simd_mix(tw.fromT, SIMD3(ahead.x, 1.6, ahead.z), SIMD3(repeating: wIn))
                tg = simd_mix(tg, tw.to.t, SIMD3(repeating: wOut))
                camTgt = tg
                camUp = simd_normalize(simd_mix(SIMD3<Float>(0, 1, 0), tw.to.up, SIMD3(repeating: wOut)))
            }
            if t >= 1 {
                camPos = tw.to.p; camTgt = tw.to.t; camUp = tw.to.up
                done = tw.onDone
                tw.onDone = nil
                tween = nil
            }
        }
        let p = camPos, tg = camTgt, up = camUp, isFree = fs.on, fov = fs.fov
        lock.unlock()

        if isFree && fov > 0, let cam = cameraNode.camera, abs(Float(cam.fieldOfView) - fov) > 0.01 {
            cam.fieldOfView = CGFloat(fov)
        }
        cameraNode.simdPosition = p
        if simd_distance(p, tg) > 1e-4 {
            let fwd = simd_normalize(tg - p)
            let safeUp = abs(simd_dot(fwd, simd_normalize(up))) > 0.999 ? SIMD3<Float>(0, 0, -1) : up
            cameraNode.simdLook(at: tg, up: safeUp, localFront: [0, 0, -1])
        }
        if let done { DispatchQueue.main.async { done() } }
        if isFree { freeFocus(renderer, time: time) }
    }

    private func stepFree(_ dt: Float) {
        let sp: Float = 3.6
        var mx: Float = 0, mz: Float = 0
        let fx = fs.joy.x, fz = -fs.joy.y
        let sy = sin(fs.yaw), cy = cos(fs.yaw)
        if fx != 0 || fz != 0 {
            fs.target = nil
            mx = (-sy * fz + cy * fx) * sp * dt
            mz = (-cy * fz - sy * fx) * sp * dt
        } else if let tg = fs.target {
            let d = SIMD2<Float>(tg.x - fs.pos.x, tg.z - fs.pos.z)
            let L = simd_length(d)
            if L < 0.08 { fs.target = nil } else {
                let s = min(L, sp * 1.4 * dt); mx = d.x / L * s; mz = d.y / L * s
            }
            if let lk = tg.look {
                let a = atan2(-(lk.x - fs.pos.x), -(lk.z - fs.pos.z))
                var da = a - fs.yaw; da = atan2(sin(da), cos(da))
                fs.yaw += da * min(1, dt * 4)
                let dh = hypot(lk.x - fs.pos.x, lk.z - fs.pos.z)
                let ptc = atan2(lk.y - 1.7, dh)
                fs.pitch += (ptc - fs.pitch) * min(1, dt * 4)
            }
        }
        if mx != 0 || mz != 0 {
            let nx = fs.pos.x + mx, nz = fs.pos.z + mz
            if Palace.walkable(nx, nz) { fs.pos.x = nx; fs.pos.z = nz }
            else if Palace.walkable(nx, fs.pos.z) { fs.pos.x = nx }
            else if Palace.walkable(fs.pos.x, nz) { fs.pos.z = nz }
            else { fs.target = nil }
        }
        fs.pitch = min(max(fs.pitch, -1.35), 1.35)
        camPos = fs.pos
        let cp = cos(fs.pitch)
        let dir = SIMD3<Float>(-sin(fs.yaw) * cp, sin(fs.pitch), -cos(fs.yaw) * cp)
        camTgt = fs.pos + dir
        camUp = [0, 1, 0]
    }

    /// En visite libre, l'élément au centre de l'écran devient l'élément courant.
    private func freeFocus(_ renderer: SCNSceneRenderer, time: TimeInterval) {
        guard time - lastFocusTime > 0.18 else { return }
        lastFocusTime = time
        lock.lock(); let p = camPos, t = camTgt; lock.unlock()
        let hits = scene.rootNode.hitTestWithSegment(from: SCNVector3(p), to: SCNVector3(p + simd_normalize(t - p) * 30),
                                                      options: [SCNHitTestOption.backFaceCulling.rawValue: true,
                                                                SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.closest.rawValue,
                                                                SCNHitTestOption.ignoreHiddenNodes.rawValue: true])
        var focus: Int? = nil
        if let h = hits.first, let name = h.node.name, name.hasPrefix("slot") { focus = Int(name.dropFirst(4)) }
        let room = Palace.roomAt(p.x, p.z) ?? lastRoom
        if (focus != nil && focus != lastFocus) || room != lastRoom {
            if focus != nil { lastFocus = focus }
            lastRoom = room
            let f = focus
            DispatchQueue.main.async { [weak self] in self?.onFreeFocus?(f, room) }
        }
    }
}


extension SceneController: UIGestureRecognizerDelegate {
    /// Le pincement peut accompagner les autres gestes (rotation du regard, toucher).
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        g is UIPinchGestureRecognizer || other is UIPinchGestureRecognizer
    }
}
