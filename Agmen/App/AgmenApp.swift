import SwiftUI

@main
struct AgmenApp: App {
    init() {
        #if DEBUG
        // D2-6: measure export speed and size on the device (`-exportSpike`); prints AGMEN-SPIKE lines.
        if ProcessInfo.processInfo.arguments.contains("-exportSpike") { Task.detached { await ExportSpike.report() } }
        #endif
    }

    /// A blank tactic; in Debug, `-openExample YES` starts from the hero move instead.
    static func newDocument() -> TacticDocument {
        #if DEBUG
        if let example = BoardDebugLaunch.newDocument() { return example }
        #endif
        return TacticDocument()
    }

    var body: some Scene {
        // The system document browser is the library (D-09).
        DocumentGroup(newDocument: Self.newDocument()) { file in
            BoardScreen(document: file.$document)
                .tint(Tokens.Colour.text.color)
        }

        // The launch screen (UI-BRIEF §4.1): the name in heavy Nunito and the tagline in Kalam over a faint chalk
        // pitch, New tactic in lime. The system title is left out because it can't take the Nunito face.
        DocumentGroupLaunchScene(Text(verbatim: "")) {
            // The scene styles this button itself (glass); a custom style is ignored, so the lime capsule waits.
            NewDocumentButton("New tactic")
                .accessibilityIdentifier("launch.new")
        } background: {
            LaunchBackground()
        }
    }
}
