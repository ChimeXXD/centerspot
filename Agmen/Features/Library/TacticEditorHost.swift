import SwiftUI

/// Edits one tactic from the library (D-56). Holds the document and its own undo history, and saves as you go:
/// shortly after each change, and always when the board closes or the app leaves the foreground.
struct TacticEditorHost: View {
    let store: LibraryStore
    let open: OpenTactic

    @State private var document: TacticDocument
    /// Where the file is now; a new title renames it on the next save.
    @State private var url: URL
    /// What's on disk, so opening a tactic without changing it doesn't move it to the top of the library.
    @State private var saved: Tactic
    @State private var undoManager = UndoManager()
    /// Names this board to the store, which saves it before opening a file handed to the app.
    @State private var board = UUID()
    @Environment(\.scenePhase) private var scenePhase

    static let saveDelay: Duration = .milliseconds(500)

    init(open: OpenTactic, store: LibraryStore) {
        self.store = store
        self.open = open
        _document = State(initialValue: TacticDocument(tactic: open.tactic))
        _url = State(initialValue: open.url)
        _saved = State(initialValue: open.tactic)
    }

    var body: some View {
        BoardScreen(document: $document, undoManager: undoManager)
            .task(id: document.tactic) {
                // Restarted by every change, so a burst of edits saves once.
                try? await Task.sleep(for: Self.saveDelay)
                guard !Task.isCancelled else { return }
                save()
            }
            .onAppear { store.registerFlush(board) { save() } }
            .onDisappear {
                store.unregisterFlush(board)
                save()
                store.close(open, at: url, leaving: document.tactic)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { save() }
            }
    }

    private func save() {
        let tactic = document.tactic
        guard tactic != saved, let newURL = store.save(tactic, to: url) else { return }
        url = newURL
        saved = tactic
    }
}
