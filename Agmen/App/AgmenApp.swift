import SwiftUI

@main
struct AgmenApp: App {
    @State private var store: LibraryStore

    init() {
        let library = TacticLibrary.documents
        #if DEBUG
        // D2-6: measure export speed and size on the device (`-exportSpike`); prints AGMEN-SPIKE lines.
        if ProcessInfo.processInfo.arguments.contains("-exportSpike") { Task.detached { await ExportSpike.report() } }
        BoardDebugLaunch.resetLibraryIfAsked(library)
        #endif
        let store = LibraryStore(library: library)
        #if DEBUG
        BoardDebugLaunch.openExampleIfAsked(store)
        #endif
        _store = State(initialValue: store)
    }

    var body: some Scene {
        // Agmen draws its own library (D-56); tactics stay `.tactic` files in Documents.
        WindowGroup {
            NavigationStack(path: Bindable(store).path) {
                LibraryScreen(store: store)
                    .navigationDestination(for: OpenTactic.self) { open in
                        TacticEditorHost(open: open, store: store)
                    }
            }
            .tint(Tokens.Colour.text.color)
            // A .tactic from AirDrop, WhatsApp or Files: checked, copied in, opened (D-56, CLAUDE.md rule 4).
            .onOpenURL { store.importAndOpen($0) }
            .alert(store.alert ?? "", isPresented: alertShown) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var alertShown: Binding<Bool> {
        Binding(get: { store.alert != nil }, set: { if !$0 { store.alert = nil } })
    }
}
