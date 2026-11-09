import SwiftUI

@main
struct CenterSpotApp: App {
    @State private var store: LibraryStore

    init() {
        // Before any export can start: clear clips an earlier run left behind when it was closed mid-export.
        VideoExporter.removeLeftovers()
        let library = TacticLibrary.documents
        #if DEBUG
        BoardDebugLaunch.onboardingIfAsked()
        #endif
        Onboarding.configure()
        #if DEBUG
        BoardDebugLaunch.resetLibraryIfAsked(library)
        BoardDebugLaunch.seedLibraryIfAsked(library)
        // D5-1: time real exports on the device (`-exportBench`); prints CENTERSPOT-EXPORT lines.
        if ProcessInfo.processInfo.arguments.contains("-exportBench"), let url = library.exampleURL,
           let hero = try? library.load(url) {
            Task.detached { await ExportBench.report(hero: hero) }
        }
        #endif
        let store = LibraryStore(library: library)
        #if DEBUG
        BoardDebugLaunch.openExampleIfAsked(store)
        #endif
        _store = State(initialValue: store)
    }

    var body: some Scene {
        // CenterSpot draws its own library (D-56); tactics stay `.tactic` files in Documents.
        WindowGroup {
            NavigationStack(path: Bindable(store).path) {
                LibraryScreen(store: store)
                    .navigationDestination(for: OpenTactic.self) { open in
                        TacticEditorHost(open: open, store: store)
                    }
            }
            .tint(Tokens.Colour.text.color)
            .modifier(WelcomeCover(store: store))
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
