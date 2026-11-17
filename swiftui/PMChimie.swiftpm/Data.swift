import SwiftUI
import UIKit

/// Un élément du palais (n = 0 pour le neutron, 1…118 pour les éléments).
struct Element: Decodable, Identifiable, Hashable {
    let n: Int
    let s: String      // symbole
    let nom: String
    let img: String    // image mentale
    let deco: String   // décryptage
    let lien: String   // action vers l'élément suivant
    var id: Int { n }
}

enum PM {
    static let maxN = 118

    static let elements: [Element] = {
        guard let url = Bundle.module.url(forResource: "elements", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Element].self, from: data) else {
            fatalError("elements.json introuvable")
        }
        return list.sorted { $0.n < $1.n }
    }()

    /// Couleurs des dizaines (code MemoHugoDate).
    static let dizHex: [UInt32] = [0xf5f5f2, 0xe53935, 0xfb8c00, 0xfdd835, 0x43a047,
                                   0x1e88e5, 0x8e24aa, 0x7b5236, 0xf48fb1, 0x9e9e9e]
    static let dizName = ["blanc", "rouge", "orange", "jaune", "vert",
                          "bleu", "violet", "marron", "rose", "gris"]
    static let surfName = ["mur gauche", "diagonale gauche", "mur du fond", "diagonale droite", "mur droit",
                           "sol à droite", "sol au centre", "sol à gauche", "plafond à gauche", "plafond à droite"]

    static func dizColor(_ d: Int) -> Color { Color(hex: dizHex[((d % 10) + 10) % 10]) }
    static func dizUIColor(_ d: Int) -> UIColor { UIColor(hex: dizHex[((d % 10) + 10) % 10]) }
    static func isDark(_ hex: UInt32) -> Bool { luminance(hex) < 0.42 }

    static func luminance(_ hex: UInt32) -> Double {
        let r = Double((hex >> 16) & 255) / 255, g = Double((hex >> 8) & 255) / 255, b = Double(hex & 255) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    static func pad(_ n: Int) -> String { String(format: "%03d", n) }

    static func whereText(_ n: Int) -> String {
        let room = n >= 100 ? 1 : 0
        let d = (n % 100) / 10, k = n % 10
        return "\(Palace.rooms[room].short) · \(room == 1 ? "1" : "")\(d)x \(surfName[d]) · case \(k)"
    }
}

// MARK: - Images

final class ImageStore {
    static let shared = ImageStore()
    private var full: [Int: UIImage] = [:]
    private var thumbs: [Int: UIImage] = [:]

    /// Image 640 px (fiche, tests).
    func image(_ n: Int) -> UIImage {
        if let im = full[n] { return im }
        let im = n == 0 ? Self.neutron(size: 640) : load(PM.pad(n)) ?? Self.placeholder(n)
        full[n] = im
        return im
    }

    /// Vignette 256 px (texture des emplacements 3D).
    func thumb(_ n: Int) -> UIImage {
        if let im = thumbs[n] { return im }
        let im = n == 0 ? Self.neutron(size: 256) : load("t" + PM.pad(n)) ?? image(n)
        thumbs[n] = im
        return im
    }

    private func load(_ name: String) -> UIImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "webp"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func placeholder(_ n: Int) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { ctx in
            UIColor.darkGray.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            let s = NSAttributedString(string: "\(n)", attributes: [.font: UIFont.boldSystemFont(ofSize: 90), .foregroundColor: UIColor.white])
            let sz = s.size(); s.draw(at: CGPoint(x: 128 - sz.width / 2, y: 128 - sz.height / 2))
        }
    }

    /// Le neutron lumineux, dessiné comme dans la version web.
    static func neutron(size: CGFloat) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: fmt).image { ctx in
            let g = ctx.cgContext, k = size / 256, c = CGPoint(x: 128 * k, y: 128 * k)
            UIColor(hex: 0x10141d).setFill(); g.fill(CGRect(x: 0, y: 0, width: size, height: size))
            let colors = [UIColor(hex: 0xf2f7ff).cgColor, UIColor(hex: 0x9fb5d8).cgColor, UIColor(hex: 0x20283a).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
                g.saveGState()
                g.addEllipse(in: CGRect(x: c.x - 96 * k, y: c.y - 96 * k, width: 192 * k, height: 192 * k)); g.clip()
                g.drawRadialGradient(grad, startCenter: c, startRadius: 10 * k, endCenter: c, endRadius: 128 * k, options: [])
                g.restoreGState()
            }
            g.setStrokeColor(UIColor(white: 1, alpha: 0.5).cgColor); g.setLineWidth(3 * k)
            for i in 0..<3 {
                g.saveGState()
                g.translateBy(x: c.x, y: c.y); g.rotate(by: CGFloat(i) * .pi / 3)
                g.strokeEllipse(in: CGRect(x: -118 * k, y: -40 * k, width: 236 * k, height: 80 * k))
                g.restoreGState()
            }
            let s = NSAttributedString(string: "n", attributes: [.font: UIFont.systemFont(ofSize: 92 * k, weight: .heavy),
                                                                 .foregroundColor: UIColor(hex: 0x14202f)])
            let sz = s.size(); s.draw(at: CGPoint(x: c.x - sz.width / 2, y: c.y - sz.height / 2 - 4 * k))
        }
    }
}

// MARK: - Couleurs

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
    static let copper = Color(hex: 0xb25a24)
    static let glowOrange = Color(hex: 0xffb347)
}
