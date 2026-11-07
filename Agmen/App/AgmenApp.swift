import SwiftUI

@main
struct AgmenApp: App {
    init() {
        #if DEBUG
        // D2-6: measure export speed and size on the device (`-exportSpike`); prints AGMEN-SPIKE lines.
        if ProcessInfo.processInfo.arguments.contains("-exportSpike") { Task.detached { await ExportSpike.report() } }
        #endif
    }

    var body: some Scene {
        // The system document browser is the library (D-09); its launch screen is customised on Day 3.
        DocumentGroup(newDocument: TacticDocument()) { file in
            BoardPlaceholderView(document: file.document)
        }
    }
}
