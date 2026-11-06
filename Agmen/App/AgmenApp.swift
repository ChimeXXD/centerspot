import SwiftUI

@main
struct AgmenApp: App {
    var body: some Scene {
        // The system document browser is the library (D-09); its launch screen is customised on Day 3.
        DocumentGroup(newDocument: TacticDocument()) { file in
            BoardPlaceholderView(document: file.document)
        }
    }
}
