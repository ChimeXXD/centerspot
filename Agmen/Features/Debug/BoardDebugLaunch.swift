#if DEBUG
import Foundation
import TipKit

/// Debug-only launch arguments for simulator screenshots and UI tests (Day 3 fidelity check, D-56).
enum BoardDebugLaunch {
    /// Before TipKit is configured. `-onboarding YES` starts the onboarding over (the welcome, then every tip);
    /// `-skipOnboarding YES`, which `-resetLibrary YES` implies, marks the welcome seen and hides the tips, so UI tests
    /// land on the library with nothing over the controls (D-78).
    static func onboardingIfAsked() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "onboarding") {
            defaults.set(false, forKey: Onboarding.welcomeSeenKey)
            try? Tips.resetDatastore()
        } else if defaults.bool(forKey: "skipOnboarding") || defaults.bool(forKey: "resetLibrary") {
            defaults.set(true, forKey: Onboarding.welcomeSeenKey)
            Tips.hideAllTipsForTesting()
        }
    }

    /// With `-resetLibrary YES`, the library starts empty and the first launch happens again (the example is added).
    static func resetLibraryIfAsked(_ library: TacticLibrary) {
        guard UserDefaults.standard.bool(forKey: "resetLibrary") else { return }
        let items = (try? FileManager.default.contentsOfDirectory(at: library.folder, includingPropertiesForKeys: nil)) ?? []
        for item in items { try? FileManager.default.removeItem(at: item) }
        library.defaults.removeObject(forKey: TacticLibrary.seededKey)
    }

    /// With `-seedLibrary N` (after `-resetLibrary YES`), N more tactics in different formations, so the library's
    /// grid can be checked full (D-74). Their names are our own words (D-13), from the mockup's library.
    static func seedLibraryIfAsked(_ library: TacticLibrary) {
        let count = UserDefaults.standard.integer(forKey: "seedLibrary")
        guard count > 0 else { return }
        let formations = ["4-4-2", "3-4-3", "5-3-2", "4-3-3", "4-2-3-1", "4-1-4-1", "3-5-2"]
            .compactMap { Presets.shared.formation($0) }
        guard !formations.isEmpty else { return }
        for n in 0..<min(count, 60) {
            var tactic = TacticDocument.blank()
            tactic.title = seedTitles[n % seedTitles.count] + (n < seedTitles.count ? "" : " \(n / seedTitles.count + 1)")
            // Already seeded on an earlier launch (without `-resetLibrary`): leave it, rather than add "… 2".
            let url = library.uniqueURL(for: tactic.title)
            guard url.deletingPathExtension().lastPathComponent == TacticLibrary.fileStem(for: tactic.title) else { continue }
            tactic = formations[n % formations.count].apply(to: tactic, stepIndex: 0)
            tactic.tokens.append(Token(id: "ball", kind: .ball))
            tactic.phases[0].steps[0].positions["ball"] = Point(x: 0.5, y: 0.5)
            _ = try? library.save(tactic, to: url)
        }
    }

    private static let seedTitles = [
        "Press their keeper", "Back three, then five", "Hold the edge of the box", "Switch to the far side",
        "Third-man run through the middle", "Near-post corner flick", "Low block after we score", "Back-post free kick",
        "Counter from our own box", "Sunday kick-off routine", "Striker drops, 10 runs beyond", "Full-backs step inside",
        "Throw-in down the line", "Trap them on the touchline", "Long ball, win the second", "Goal kick: play out short",
        "Wing-back underlap", "Cut-back from the byline", "Keeper sweeps behind a high line", "Two up top, both press",
        "Late run from the edge",
    ]

    /// With `-openExample YES`, the app opens straight onto the hero move (D-29), adding it if it was deleted.
    @MainActor static func openExampleIfAsked(_ store: LibraryStore) {
        guard UserDefaults.standard.bool(forKey: "openExample") else { return }
        store.openExample()
    }
}
#endif
