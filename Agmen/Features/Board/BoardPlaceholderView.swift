import SwiftUI

/// Day 0 stand-in for the board, so a document opens to something. Replaced on Day 3.
struct BoardPlaceholderView: View {
    let document: TacticDocument

    private var stepCount: Int { document.tactic.phases.reduce(0) { $0 + $1.steps.count } }

    var body: some View {
        ContentUnavailableView(
            "Agmen",
            systemImage: "sportscourt",
            description: Text("The board arrives on Day 3. \(document.tactic.title) has ^[\(document.tactic.tokens.count) token](inflect: true) and ^[\(stepCount) step](inflect: true).")
        )
    }
}
