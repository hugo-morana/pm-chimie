import SwiftUI
import Observation
import simd

/// Ce que l'interface masque pendant un test.
struct TestLook: Equatable {
    var hideImg: Int? = nil
    var mask = false       // nom et image mentale masqués dans la fiche
    var maskAll = false    // numéro aussi
    var compact = false    // fiche réduite
    var noDim = false
    var noHL = false
}

@Observable
final class PalaceModel {
    enum Mode { case guided, free }

    var n: Int = 0                 // -1 : pièce sans élément choisi
    var room = 0
    var lvl: Int = UserDefaults.standard.object(forKey: "pm.lvl") as? Int ?? 2
    var mode: Mode = .guided
    var showChain = false
    var bannerFrom: Int? = nil
    var testLook: TestLook? = nil
    var session: TestSession? = nil
    var endMessage: String? = nil
    var showTests = false
    var showPlan = false
    var ficheCollapsed = false

    let srs = SRSStore()
    @ObservationIgnored let scene = SceneController()
    @ObservationIgnored private var started = false
    @ObservationIgnored private var bannerTask: Task<Void, Never>? = nil

    static let zoomNames = ["Vue d'ensemble", "Panneau", "Emplacement"]

    init() {
        scene.onTapSlot = { [weak self] n in self?.slotTapped(n) }
        scene.onSwipe = { [weak self] d in self?.stepN(d) }
        scene.onFreeFocus = { [weak self] f, r in
            guard let self, self.mode == .free else { return }
            self.room = r
            if let f { self.n = f }
            self.refreshScene()
        }
    }

    /// Premier affichage, une fois la vue dimensionnée.
    func startIfNeeded() {
        guard !started else { return }
        started = true
        go(0, instant: true)
    }

    func refreshScene() {
        if testLook == nil { UserDefaults.standard.set(lvl, forKey: "pm.lvl") }
        let T = testLook
        scene.apply(SlotLook(current: n, room: room, lvl: lvl, free: mode == .free, showChain: showChain,
                             hideImg: T?.hideImg, noDim: T?.noDim ?? false, noHL: T?.noHL ?? false))
    }

    private func afterArrive() {
        if mode == .guided { scene.setOverviewHidden(lvl == 0 || n < 0) }
    }

    // MARK: Navigation guidée

    func go(_ target: Int, link: Bool = false, instant: Bool = false, fast: Bool = false) {
        scene.finishTween()
        let prev = n, fromRoom = room
        n = target
        if target >= 0 { room = Palace.slots[target].room }
        if mode == .free { mode = .guided }
        let v = scene.cameraView(for: target, lvl: lvl, room: room)
        scene.setOverviewHidden(false)
        let dur = scene.move(to: v, fromRoom: fromRoom, toRoom: room, duration: fast ? 0.42 : 0.65, instant: instant) { [weak self] in
            self?.afterArrive()
        }
        if link, prev >= 0, target >= 0, abs(prev - target) == 1 {
            let a = min(prev, target)
            scene.showWire(from: prev, to: target, duration: fromRoom != room ? dur * 0.9 : 0.8)
            showBanner(a)
        }
        refreshScene()
    }

    func goRoom(_ r: Int) {
        guard session == nil else { return }
        scene.finishTween()
        let from = room
        room = r
        n = -1
        if mode == .free {
            scene.enterFree(at: Palace.rooms[r].origin + [0, 1.7, 6.2], yaw: 0)
        } else {
            let v = scene.cameraView(for: -1, lvl: 0, room: r)
            scene.setOverviewHidden(false)
            scene.move(to: v, fromRoom: from, toRoom: r, duration: 0.6) { [weak self] in self?.afterArrive() }
        }
        refreshScene()
    }

    func stepN(_ d: Int) {
        guard session == nil else { return }
        let t: Int
        if n < 0 {
            t = d > 0 ? Palace.rooms[room].first : (room == 0 ? PM.maxN : Palace.rooms[room].first - 1)
        } else {
            t = (n + d + PM.maxN + 1) % (PM.maxN + 1)
        }
        go(t, link: true)
    }

    func stepD(_ d: Int) {
        guard session == nil else { return }
        let cur = n < 0 ? Palace.rooms[room].first : n
        var t: Int
        if d > 0 {
            t = (cur / 10 + 1) * 10
            if t > PM.maxN { t = 0 }
        } else {
            t = cur % 10 != 0 ? (cur / 10) * 10 : cur - 10
            if t < 0 { t = (PM.maxN / 10) * 10 }
        }
        go(t)
    }

    func cycleZoom() {
        guard session == nil else { return }
        lvl = (lvl + 1) % 3
        if n < 0 && lvl > 0 { n = Palace.rooms[room].first }
        mode = .guided
        let v = scene.cameraView(for: n, lvl: lvl, room: room)
        scene.setOverviewHidden(false)
        scene.move(to: v, fromRoom: room, toRoom: room, duration: 0.5) { [weak self] in self?.afterArrive() }
        refreshScene()
    }

    func toggleChain() {
        showChain.toggle()
        if showChain && lvl != 0 { lvl = 2; cycleZoom() } else { refreshScene() }
    }

    func setMode(_ m: Mode) {
        guard m != mode, session == nil else { return }
        if m == .free {
            mode = .free
            scene.setOverviewHidden(false)
            scene.enterFree()
        } else {
            go(n < 0 ? Palace.rooms[room].first : n)
        }
        refreshScene()
    }

    func slotTapped(_ t: Int) {
        guard session == nil else { return }
        if mode == .free {
            n = t; room = Palace.slots[t].room
            refreshScene()
        } else {
            go(t, link: n >= 0 && abs(n - t) == 1)
        }
    }

    func reframe() {
        guard started, mode == .guided else { return }
        let v = scene.cameraView(for: n, lvl: lvl, room: room)
        scene.move(to: v, fromRoom: room, toRoom: room, duration: 0.35)
    }

    func showBanner(_ a: Int) {
        bannerFrom = a
        bannerTask?.cancel()
        bannerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4.8))
            guard !Task.isCancelled else { return }
            withAnimation { self?.bannerFrom = nil }
        }
    }

    // MARK: Tests

    /// Lance une séance ; renvoie un message si elle ne peut pas commencer.
    func startSession(_ kind: TestSession.Kind) -> String? {
        if srs.selNums().isEmpty { return "Choisis au moins une dizaine." }
        guard let s = TestSession.make(kind, srs: srs) else {
            switch kind {
            case .learn: return "Tous les éléments sélectionnés sont déjà appris."
            case .review: return "Rien à revoir aujourd'hui dans cette sélection."
            default: return "Rien à tester dans cette sélection."
            }
        }
        if mode == .free { mode = .guided }
        session = s
        showTests = false
        bannerFrom = nil
        ficheCollapsed = false
        nextCard()
        return nil
    }

    func nextCard() {
        guard var s = session else { return }
        if let msg = s.next() { endSession(msg); return }
        session = s
        if let c = s.current { ask(c) }
    }

    private func travelOverview(_ t: Int) {
        lvl = 0
        n = t
        let from = room
        room = Palace.slots[t].room
        let v = scene.cameraView(for: t, lvl: 0, room: room)
        scene.setOverviewHidden(false)
        scene.move(to: v, fromRoom: from, toRoom: room, duration: 0.5) { [weak self] in self?.afterArrive() }
    }

    private func ask(_ c: TestCard) {
        let t = c.n
        switch c.kind {
        case .present:
            testLook = TestLook()
            lvl = 2
            go(t)
            if t > 0 { scene.showWire(from: t - 1, to: t, duration: 0.9) }
        case .rehearse, .n2i:
            testLook = TestLook(hideImg: t, mask: true, compact: true, noDim: true)
            travelOverview(t)
        case .i2n:
            testLook = TestLook(mask: true, maskAll: true, compact: true, noHL: true)
            travelOverview(t)
        case .chainStart:
            testLook = TestLook(compact: true)
            lvl = 2
            go(t)
        case .suite, .chainStep:
            testLook = TestLook(hideImg: t + 1, compact: true, noDim: true)
            travelOverview(t)
        }
        refreshScene()
    }

    /// Montre la réponse dans le palais.
    func reveal() {
        guard var s = session, let c = s.current else { return }
        s.revealed = true
        session = s
        var target = c.n
        var from: Int? = nil
        if c.kind == .suite || c.kind == .chainStep { target = c.n + 1; from = c.n }
        else if c.kind == .rehearse && c.n > 0 { from = c.n - 1 }
        testLook = TestLook()
        lvl = 0
        go(target)
        if let from {
            let cross = Palace.slots[from].room != Palace.slots[target].room
            scene.showWire(from: from, to: target, duration: cross ? 2.6 : 1.0)
            showBanner(from)
        }
    }

    func answer(_ value: Int?) {
        guard var s = session else { return }
        s.answer(value, srs: srs)
        session = s
        let c = s.current!
        testLook = TestLook()
        lvl = 0
        go(c.n)
    }

    func judge(_ ok: Bool) {
        guard var s = session else { return }
        s.judge(ok, srs: srs)
        session = s
        nextCard()
    }

    func endSession(_ msg: String? = nil) {
        session = nil
        testLook = nil
        bannerFrom = nil
        refreshScene()
        if let msg { endMessage = msg; showTests = true }
    }

    // MARK: Fiche

    var whereText: String { n >= 0 ? PM.whereText(n) : "" }
}
