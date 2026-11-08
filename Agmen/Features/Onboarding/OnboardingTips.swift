import SwiftUI
import TipKit

/// The five tips on the example move (D-58, D-78, mockup `tip-*--bc`), shown one at a time in this order. Each is done
/// when the user does what it says; × closes it. Either way the next one can come, and a finished tip never returns
/// until Show tips again.
struct DragTip: Tip {
    var title: Text { Text("Move a player") }
    var message: Text? { Text("Drag any player to where they should be.") }
}

struct StepTip: Tip {
    var title: Text { Text("Every step is a moment") }
    var message: Text? { Text("Tap step 2 to see where everyone goes.") }
}

struct PlayTip: Tip {
    var title: Text { Text("Watch it move") }
    var message: Text? { Text("Press Play to run the move. Pick Flat or Broadcast at the top.") }
}

struct DrawTip: Tip {
    var title: Text { Text("Draw a run") }
    var message: Text? { Text("Tap Draw, then drag from a player to show their run.") }
}

struct ExportTip: Tip {
    var title: Text { Text("Share the clip") }
    var message: Text? { Text("Export turns it into a 9:16 video.") }
}

/// Whether the welcome has been seen, and the tips in order (D-58, D-78). One for the app; the board asks it which tip
/// is due and tells it what the user did.
@MainActor @Observable
final class Onboarding {
    static let shared = Onboarding()
    /// `UserDefaults` key: the welcome pages have been finished or skipped.
    nonisolated static let welcomeSeenKey = "welcomeSeen"

    /// The five tips, ordered: only the first not yet done or closed shows. Rebuilt by Show tips again.
    private(set) var tips = Onboarding.makeGroup()

    private static func makeGroup() -> TipGroup {
        TipGroup(.ordered) { DragTip(); StepTip(); PlayTip(); DrawTip(); ExportTip() }
    }

    /// The step the "Every step is a moment" tip points at: step 2, or step 1 when there is only one (D-78).
    nonisolated static func stepTipIndex(stepCount: Int) -> Int { min(1, stepCount - 1) }

    /// The tip due now, if it is of type `T` (each anchor asks for its own).
    func current<T: Tip>(_ type: T.Type) -> T? { tips.currentTip as? T }

    /// The user did what `tip` says (dragged a player, tapped a step…): it's done and the next can come.
    func done(_ tip: some Tip) {
        tip.invalidate(reason: .actionPerformed)
    }

    /// Show tips again (D-78): every tip comes back, and the welcome shows from page 1.
    func showAgain() async {
        for tip in [DragTip(), StepTip(), PlayTip(), DrawTip(), ExportTip()] as [any Tip] {
            await tip.resetEligibility()
        }
        tips = Self.makeGroup()
        UserDefaults.standard.set(false, forKey: Self.welcomeSeenKey)
    }

    /// Before any tip is shown: TipKit's store, kept between launches.
    static func configure() {
        try? Tips.configure([.displayFrequency(.immediate)])
    }
}
