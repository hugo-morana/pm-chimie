import Foundation
import Observation

/// Répétition espacée, même modèle que la version web :
/// chaque fiche est dans une boîte 0…5 et revient après 0, 1, 2, 4, 8 ou 16 jours.
/// Clés : "P<n>" (emplacement ↔ image) et "L<n>" (lien n → n+1).
@Observable
final class SRSStore {
    struct Card: Codable, Equatable { var box: Int; var due: Int }

    static let intervals = [0, 1, 2, 4, 8, 16]
    static let dzCount = PM.maxN / 10 + 1   // 12 dizaines : 0x…11x
    static let boxColors: [UInt32] = [0x9e9e9e, 0xef9a9a, 0xffcc80, 0xfff176, 0xa5d6a7, 0x43a047]

    private(set) var cards: [String: Card] = [:]
    private(set) var sel: [Int] = Array(0..<SRSStore.dzCount)
    private(set) var newPer: Int = 8

    private struct Saved: Codable { var cards: [String: Card]; var sel: [Int]; var newPer: Int }
    private let key = "pm.srs.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(Saved.self, from: data) {
            cards = s.cards; sel = s.sel; newPer = s.newPer
        }
    }

    private func save() {
        let s = Saved(cards: cards, sel: sel, newPer: newPer)
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) }
    }

    static func today() -> Int {
        let now = Date()
        let offset = TimeInterval(TimeZone.current.secondsFromGMT(for: now))
        return Int(floor((now.timeIntervalSince1970 + offset) / 86400))
    }

    func card(_ k: String) -> Card? { cards[k] }

    func grade(_ k: String, ok: Bool) {
        let b = ok ? min((cards[k]?.box ?? 0) + 1, 5) : 0
        cards[k] = Card(box: b, due: Self.today() + Self.intervals[b])
        save()
    }

    /// Fin de l'apprentissage d'un nouvel élément : boîte 1, et son lien entrant s'il est nouveau.
    func learned(_ n: Int) {
        let t = Self.today()
        cards["P\(n)"] = Card(box: 1, due: t + 1)
        if n > 0, cards["L\(n - 1)"] == nil { cards["L\(n - 1)"] = Card(box: 1, due: t + 1) }
        save()
    }

    func reset() { cards = [:]; save() }

    func toggle(_ d: Int) {
        if let i = sel.firstIndex(of: d) { sel.remove(at: i) } else { sel.append(d) }
        save()
    }

    func selectAll(_ on: Bool) { sel = on ? Array(0..<Self.dzCount) : []; save() }

    func setNewPer(_ v: Int) { newPer = min(30, max(2, v)); save() }

    func selNums() -> [Int] { (0...PM.maxN).filter { sel.contains($0 / 10) } }
    func newNums() -> [Int] { selNums().filter { cards["P\($0)"] == nil } }

    func dueCards() -> [TestCard] {
        let t = Self.today()
        var out: [TestCard] = []
        for n in selNums() {
            if let p = cards["P\(n)"], p.due <= t { out.append(TestCard(kind: Bool.random() ? .n2i : .i2n, n: n)) }
            if n < PM.maxN, let l = cards["L\(n)"], l.due <= t { out.append(TestCard(kind: .suite, n: n)) }
        }
        return out.shuffled()
    }
}

/// Une question de test.
struct TestCard: Equatable {
    enum Kind: Equatable { case present, rehearse, n2i, i2n, suite, chainStart, chainStep }
    var kind: Kind
    var n: Int
    var key: String { kind == .suite || kind == .chainStep ? "L\(n)" : "P\(n)" }
}

/// Une séance de test en cours.
struct TestSession {
    enum Kind: String { case learn, review, n2i, i2n, suite, chain }

    struct Active: Equatable { var n: Int; var step: Int; var at: Int }

    let kind: Kind
    var total = 0
    var done = 0
    var ok = 0
    var queue: [TestCard] = []
    // apprentissage
    var fresh: [Int] = []
    var active: [Active] = []
    var clock = 0
    // chaîne
    var chainA = 0, chainB = 0, chainI = 0, chainStarted = false

    var current: TestCard?
    var revealed = false
    var typed: Int?
    var autoResult: Bool?   // résultat automatique (image → numéro)

    var progressText: String {
        switch kind {
        case .learn: return "\(fresh.count + active.count) en cours"
        case .chain: return "\(chainI - chainA)/\(total)"
        default: return "\(done)/\(total)"
        }
    }

    var title: String {
        switch kind {
        case .learn: return "Apprentissage"
        case .review: return "Révision du jour"
        case .n2i: return "Numéro → image"
        case .i2n: return "Image → numéro"
        case .suite: return "Suite"
        case .chain: return "Chaîne"
        }
    }

    /// Crée la séance ; nil s'il n'y a rien à faire.
    static func make(_ kind: Kind, srs: SRSStore) -> TestSession? {
        let nums = srs.selNums()
        guard !nums.isEmpty else { return nil }
        var s = TestSession(kind: kind)
        switch kind {
        case .learn:
            s.fresh = Array(srs.newNums().prefix(srs.newPer))
            guard !s.fresh.isEmpty else { return nil }
            s.total = s.fresh.count
        case .review:
            s.queue = srs.dueCards()
            guard !s.queue.isEmpty else { return nil }
            s.total = s.queue.count
        case .chain:
            let ds = srs.sel.filter { $0 < SRSStore.dzCount }
            guard let d = ds.randomElement() else { return nil }
            s.chainA = d * 10; s.chainB = min(d * 10 + 9, PM.maxN); s.chainI = s.chainA
            s.total = s.chainB - s.chainA
        case .n2i, .i2n, .suite:
            let pool = kind == .suite ? nums.filter { $0 < PM.maxN } : nums
            let k: TestCard.Kind = kind == .suite ? .suite : (kind == .n2i ? .n2i : .i2n)
            s.queue = pool.shuffled().prefix(20).map { TestCard(kind: k, n: $0) }
            s.total = s.queue.count
        }
        return s
    }

    /// Passe à la question suivante ; renvoie un message de fin quand la séance est terminée.
    mutating func next() -> String? {
        revealed = false; typed = nil; autoResult = nil
        switch kind {
        case .learn:
            if let due = active.filter({ $0.at <= clock }).min(by: { $0.at < $1.at }) {
                current = TestCard(kind: .rehearse, n: due.n)
            } else if active.count < 4, !fresh.isEmpty {
                let n = fresh.removeFirst()
                active.append(Active(n: n, step: 0, at: clock + 2))
                current = TestCard(kind: .present, n: n)
            } else if let it = active.min(by: { $0.at < $1.at }) {
                clock = it.at
                current = TestCard(kind: .rehearse, n: it.n)
            } else {
                current = nil
                return "Séance terminée : \(total) nouveaux éléments appris"
            }
            clock += 1
        case .chain:
            if chainI == chainA && !chainStarted {
                chainStarted = true
                current = TestCard(kind: .chainStart, n: chainA)
            } else if chainI >= chainB {
                current = nil
                return "Chaîne terminée : \(ok)/\(total) liens retrouvés"
            } else {
                current = TestCard(kind: .chainStep, n: chainI)
            }
        default:
            guard !queue.isEmpty else {
                current = nil
                return "Séance terminée : \(ok)/\(total) réussies"
            }
            current = queue.removeFirst()
        }
        return nil
    }

    /// Réponse « Je savais » / « Raté ».
    mutating func judge(_ ok: Bool, srs: SRSStore) {
        guard let c = current else { return }
        switch c.kind {
        case .rehearse:
            guard let i = active.firstIndex(where: { $0.n == c.n }) else { return }
            if ok {
                active[i].step += 1
                if active[i].step >= 3 {
                    active.remove(at: i)
                    srs.learned(c.n)
                } else {
                    active[i].at = clock + [2, 5, 10][active[i].step]
                }
            } else {
                active[i].step = 0
                active[i].at = clock + 2
            }
        case .chainStep:
            srs.grade(c.key, ok: ok)
            if ok { self.ok += 1 }
            chainI += 1
        default:
            srs.grade(c.key, ok: ok)
            done += 1
            if ok { self.ok += 1 }
        }
    }

    /// Réponse tapée (image → numéro), notée automatiquement.
    mutating func answer(_ value: Int?, srs: SRSStore) {
        guard let c = current else { return }
        let ok = value == c.n
        typed = value
        autoResult = ok
        srs.grade(c.key, ok: ok)
        done += 1
        if ok { self.ok += 1 }
        revealed = true
    }
}
