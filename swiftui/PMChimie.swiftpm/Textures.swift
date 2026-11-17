import UIKit

/// Textures dessinées par programme (comme les <canvas> de la version web).
enum Tex {
    private static func draw(_ w: CGFloat, _ h: CGFloat, _ body: (CGContext, CGFloat, CGFloat) -> Void) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { body($0.cgContext, w, h) }
    }

    /// Générateur pseudo-aléatoire déterministe (même formule que rnd() en JS).
    struct Rnd {
        var s: UInt32
        init(_ seed: UInt32) { s = seed }
        mutating func next() -> CGFloat {
            s = s &* 1664525 &+ 1013904223
            return CGFloat(s) / 4294967296
        }
    }

    private static func noise(_ g: CGContext, _ w: CGFloat, _ h: CGFloat, alpha: CGFloat, seed: UInt32, count: Int) {
        var r = Rnd(seed)
        for _ in 0..<count {
            let c: CGFloat = r.next() < 0.5 ? 0 : 1
            g.setFillColor(UIColor(white: c, alpha: alpha * r.next()).cgColor)
            g.fill(CGRect(x: r.next() * w, y: r.next() * h, width: 1 + r.next() * 2, height: 1 + r.next() * 2))
        }
    }

    // MARK: Laboratoire moderne

    static let mFloor = draw(512, 512) { g, _, _ in
        var r = Rnd(3)
        for y in 0..<4 { for x in 0..<4 {
            let v = (214 + floor(r.next() * 14)) / 255
            g.setFillColor(UIColor(red: v, green: v + 3 / 255, blue: v + 6 / 255, alpha: 1).cgColor)
            g.fill(CGRect(x: x * 128, y: y * 128, width: 128, height: 128))
            g.setStrokeColor(UIColor(white: 0.6, alpha: 1).cgColor); g.setLineWidth(2)
            g.stroke(CGRect(x: x * 128, y: y * 128, width: 128, height: 128))
        } }
    }

    static let mWall = draw(512, 512) { g, w, h in
        g.setFillColor(UIColor(hex: 0xc7ccd1).cgColor); g.fill(CGRect(x: 0, y: 0, width: w, height: h))
        var r = Rnd(7)
        for _ in 0..<900 {
            let y = r.next() * h
            let light = r.next() < 0.5
            g.setStrokeColor(UIColor(white: light ? 1 : 0.38, alpha: 0.06 + r.next() * 0.08).cgColor)
            g.setLineWidth(1)
            g.move(to: CGPoint(x: r.next() * w, y: y)); g.addLine(to: CGPoint(x: r.next() * w, y: y + r.next() * 2)); g.strokePath()
        }
        g.setStrokeColor(UIColor(hex: 0x9aa1a7).cgColor); g.setLineWidth(3)
        g.stroke(CGRect(x: 0, y: 0, width: w, height: h))
    }

    static let mCeil = draw(512, 512) { g, w, h in
        g.setFillColor(UIColor(hex: 0xe9edf0).cgColor); g.fill(CGRect(x: 0, y: 0, width: w, height: h))
        g.setFillColor(UIColor(hex: 0xbfe2f4).cgColor)
        for y in 0..<2 { for x in 0..<2 { g.fill(CGRect(x: x * 256 + 28, y: y * 256 + 28, width: 200, height: 200)) } }
    }

    // MARK: Laboratoire d'alchimiste

    static let aFloor = draw(512, 512) { g, _, _ in
        var r = Rnd(11)
        for y in 0..<4 { for x in 0..<4 {
            let b = 180 + r.next() * 30
            g.setFillColor(UIColor(red: (b + 20) / 255, green: (b + 2) / 255, blue: (b - 26) / 255, alpha: 1).cgColor)
            g.fill(CGRect(x: x * 128, y: y * 128, width: 128, height: 128))
            g.setStrokeColor(UIColor(red: 0.47, green: 0.35, blue: 0.24, alpha: 0.5).cgColor); g.setLineWidth(3)
            g.stroke(CGRect(x: x * 128, y: y * 128, width: 128, height: 128))
        } }
    }

    static let aWall = draw(512, 512) { g, w, h in
        g.setFillColor(UIColor(hex: 0x6e4123).cgColor); g.fill(CGRect(x: 0, y: 0, width: w, height: h))
        var r = Rnd(17)
        for x in 0..<8 {
            let b = r.next() * 18
            g.setFillColor(UIColor(red: (110 + b) / 255, green: (66 + b * 0.6) / 255, blue: (36 + b * 0.3) / 255, alpha: 1).cgColor)
            g.fill(CGRect(x: CGFloat(x) * 64 + 2, y: 0, width: 60, height: h))
            for _ in 0..<14 {
                g.setStrokeColor(UIColor(red: 50 / 255, green: 26 / 255, blue: 10 / 255, alpha: 0.15 + r.next() * 0.2).cgColor)
                g.setLineWidth(1)
                let xx = CGFloat(x) * 64 + 4 + r.next() * 56
                g.move(to: CGPoint(x: xx, y: 0)); g.addLine(to: CGPoint(x: xx + r.next() * 4 - 2, y: h)); g.strokePath()
            }
        }
    }

    static let aCeil = draw(512, 512) { g, w, h in
        g.setFillColor(UIColor(hex: 0xd9ecf2).cgColor); g.fill(CGRect(x: 0, y: 0, width: w, height: h))
        g.setFillColor(UIColor(hex: 0x5a3418).cgColor)
        for r in [CGRect(x: 0, y: 0, width: w, height: 26), CGRect(x: 0, y: 243, width: w, height: 26),
                  CGRect(x: 0, y: 0, width: 26, height: h), CGRect(x: 243, y: 0, width: 26, height: h)] { g.fill(r) }
    }

    static let rug = draw(512, 512) { g, w, h in
        g.setFillColor(UIColor(hex: 0x6b1f1a).cgColor); g.fill(CGRect(x: 0, y: 0, width: w, height: h))
        g.setStrokeColor(UIColor(hex: 0xc99a4a).cgColor)
        g.setLineWidth(10); g.stroke(CGRect(x: 20, y: 20, width: w - 40, height: h - 40))
        g.setLineWidth(4); g.stroke(CGRect(x: 46, y: 46, width: w - 92, height: h - 92))
        g.setFillColor(UIColor(hex: 0x1e3a5a).cgColor)
        g.fillEllipse(in: CGRect(x: w / 2 - 150, y: h / 2 - 110, width: 300, height: 220))
        g.setLineWidth(6); g.strokeEllipse(in: CGRect(x: w / 2 - 150, y: h / 2 - 110, width: 300, height: 220))
    }

    // MARK: Couloir

    static let cFloor = draw(256, 256) { g, w, h in
        g.setFillColor(UIColor(hex: 0x8f969c).cgColor); g.fill(CGRect(x: 0, y: 0, width: w, height: h))
        noise(g, w, h, alpha: 0.18, seed: 19, count: 2500)
        g.setStrokeColor(UIColor(hex: 0x757c82).cgColor); g.setLineWidth(2); g.stroke(CGRect(x: 0, y: 0, width: w, height: h))
    }

    static let cWall = draw(256, 256) { g, w, h in
        g.setFillColor(UIColor(hex: 0xe4e0d9).cgColor); g.fill(CGRect(x: 0, y: 0, width: w, height: h))
        noise(g, w, h, alpha: 0.06, seed: 23, count: 1500)
        g.setFillColor(UIColor(hex: 0x4b4f55).cgColor); g.fill(CGRect(x: 0, y: h - 22, width: w, height: 22))
    }

    // MARK: Panneaux d'une dizaine

    static func panel(alchemist alch: Bool, d: Int) -> UIImage {
        let ppu: CGFloat = 180
        let pl = CGFloat(Palace.pl), pt = CGFloat(Palace.pt)
        let W = (CGFloat(Palace.pr) - pl) * ppu, H = (pt - CGFloat(Palace.pb)) * ppu
        let px: (CGFloat) -> CGFloat = { ($0 - pl) * ppu }
        let py: (CGFloat) -> CGFloat = { (pt - $0) * ppu }
        let baseHex = PM.dizHex[d]
        return draw(W.rounded(), H.rounded()) { g, w, h in
            g.setFillColor(UIColor(hex: baseHex).cgColor); g.fill(CGRect(x: 0, y: 0, width: w, height: h))
            noise(g, w, h, alpha: 0.05, seed: UInt32(31 + d), count: 1600)
            let cs = 0.9 * ppu
            for k in 0..<10 {
                let l = Palace.cellLocal(k)
                let x0 = px(CGFloat(l.x) - 0.45), y0 = py(CGFloat(l.y) + 0.45)
                var fill = baseHex
                if alch {
                    if k == 0 { fill = 0xd32f2f } else {
                        let rc = Palace.cellRC[k]!
                        fill = (rc.0 + rc.1) % 2 == 1 ? 0xd32f2f : (d == 1 ? 0x151515 : baseHex)
                    }
                }
                g.setFillColor(UIColor(hex: fill).cgColor); g.fill(CGRect(x: x0, y: y0, width: cs, height: cs))
                g.setStrokeColor(UIColor(hex: 0x121212).cgColor); g.setLineWidth(7)
                g.stroke(CGRect(x: x0 + 3, y: y0 + 3, width: cs - 6, height: cs - 6))
                let num = (alch ? 100 : 0) + d * 10 + k
                let dark = PM.isDark(fill)
                let s = NSAttributedString(string: "\(num)", attributes: [
                    .font: UIFont.systemFont(ofSize: alch ? 34 : 40, weight: .bold),
                    .foregroundColor: dark ? UIColor.white : UIColor(hex: 0x111111)])
                UIGraphicsPushContext(g); s.draw(at: CGPoint(x: x0 + 12, y: y0 + 6)); UIGraphicsPopContext()
                if num > PM.maxN {
                    g.setFillColor(dark ? UIColor(white: 1, alpha: 0.18).cgColor : UIColor(white: 0, alpha: 0.12).cgColor)
                    g.fill(CGRect(x: x0 + cs * 0.3, y: y0 + cs * 0.3, width: cs * 0.55, height: cs * 0.55))
                }
            }
            // cartouche de la dizaine
            let cx = px(0), cy = py(1.68), cw = 1.45 * ppu, ch = 0.72 * ppu
            let path = UIBezierPath(roundedRect: CGRect(x: cx, y: cy, width: cw, height: ch), cornerRadius: 18)
            g.setFillColor(UIColor(hex: alch ? 0x2a160a : 0x1d2126).cgColor); g.addPath(path.cgPath); g.fillPath()
            g.setStrokeColor(UIColor(hex: alch ? 0xc9a043 : 0xc7ccd1).cgColor); g.setLineWidth(5); g.addPath(path.cgPath); g.strokePath()
            let t = NSAttributedString(string: (alch ? "1" : "") + "\(d)x", attributes: [
                .font: UIFont.systemFont(ofSize: alch ? 74 : 84, weight: .black), .foregroundColor: UIColor.white])
            let ts = t.size()
            UIGraphicsPushContext(g); t.draw(at: CGPoint(x: cx + cw / 2 - ts.width / 2, y: cy + ch / 2 - ts.height / 2)); UIGraphicsPopContext()
            g.setStrokeColor(UIColor(hex: alch ? 0x3b2210 : 0x2b3036).cgColor); g.setLineWidth(12)
            g.stroke(CGRect(x: 6, y: 6, width: w - 12, height: h - 12))
        }
    }

    /// Enseigne d'une pièce, côté couloir.
    static func sign(_ room: Palace.Room) -> UIImage {
        let m = !room.alchemist
        return draw(1040, 190) { g, w, h in
            g.setFillColor(UIColor(hex: m ? 0x1d2126 : 0x2a160a).cgColor); g.fill(CGRect(x: 0, y: 0, width: w, height: h))
            g.setStrokeColor(UIColor(hex: m ? 0xc7ccd1 : 0xc9a043).cgColor); g.setLineWidth(8)
            g.stroke(CGRect(x: 6, y: 6, width: w - 12, height: h - 12))
            UIGraphicsPushContext(g)
            let a = NSAttributedString(string: room.name, attributes: [.font: UIFont.systemFont(ofSize: 58, weight: .heavy), .foregroundColor: UIColor.white])
            let sa = a.size(); a.draw(at: CGPoint(x: w / 2 - sa.width / 2, y: h * 0.4 - sa.height / 2))
            let b = NSAttributedString(string: room.range, attributes: [.font: UIFont.monospacedSystemFont(ofSize: 40, weight: .medium),
                                                                         .foregroundColor: UIColor(hex: m ? 0xc7ccd1 : 0xe8c977)])
            let sb = b.size(); b.draw(at: CGPoint(x: w / 2 - sb.width / 2, y: h * 0.76 - sb.height / 2))
            UIGraphicsPopContext()
        }
    }
}
