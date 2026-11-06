import SwiftUI

/// Day 0 stand-in for the board, so a document opens to something. Replaced on Day 3.
struct BoardPlaceholderView: View {
    let document: TacticDocument

    var body: some View {
        ContentUnavailableView(
            "Agmen",
            systemImage: "sportscourt",
            description: Text("The board arrives on Day 3. This tactic is \(document.data.count) bytes.")
        )
    }
}
