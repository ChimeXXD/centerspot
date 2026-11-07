#if DEBUG
import Foundation

/// Debug-only launch arguments for simulator screenshots and UI tests (Day 3 fidelity check, D-56).
enum BoardDebugLaunch {
    /// With `-resetLibrary YES`, the library starts empty and the first launch happens again (the example is added).
    static func resetLibraryIfAsked(_ library: TacticLibrary) {
        guard UserDefaults.standard.bool(forKey: "resetLibrary") else { return }
        let items = (try? FileManager.default.contentsOfDirectory(at: library.folder, includingPropertiesForKeys: nil)) ?? []
        for item in items { try? FileManager.default.removeItem(at: item) }
        library.defaults.removeObject(forKey: TacticLibrary.seededKey)
    }

    /// With `-openExample YES`, the app opens straight onto the hero move (D-29), adding it if it was deleted.
    @MainActor static func openExampleIfAsked(_ store: LibraryStore) {
        guard UserDefaults.standard.bool(forKey: "openExample"),
              let exampleURL = store.library.exampleURL,
              let example = try? store.library.load(exampleURL)
        else { return }
        if let entry = store.entries.first(where: { $0.tactic.id == example.id }) {
            store.open(entry.url)
        } else {
            store.importAndOpen(exampleURL)
        }
    }
}
#endif
