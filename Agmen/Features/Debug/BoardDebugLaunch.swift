#if DEBUG
import Foundation

/// Debug-only launch arguments for simulator screenshots and UI tests (Day 3 fidelity check).
enum BoardDebugLaunch {
    /// With `-openExample YES`, New tactic starts from the bundled hero move (D-29) instead of a blank board.
    static func newDocument() -> TacticDocument? {
        guard UserDefaults.standard.bool(forKey: "openExample"),
              let url = Bundle.main.url(forResource: "overlap-left", withExtension: "tactic"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? TacticDocument(data: data)
    }
}
#endif
