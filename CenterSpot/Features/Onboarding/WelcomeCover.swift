import SwiftUI

/// Shows the welcome over the library until it has been seen (D-58): on first launch, and after Show tips again. Skip
/// lands on the library; Start opens the example move. Without the bundled example there is nothing to show, so it
/// counts as seen.
struct WelcomeCover: ViewModifier {
    let store: LibraryStore
    @AppStorage(Onboarding.welcomeSeenKey) private var welcomeSeen = false
    /// The bundled example, read once (not on every body pass and binding read).
    @State private var example: Tactic?

    init(store: LibraryStore) {
        self.store = store
        _example = State(initialValue: store.library.exampleURL.flatMap { try? store.library.load($0) })
    }

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: showing) {
            if let example {
                WelcomeView(tactic: example, onSkip: { welcomeSeen = true }, onStart: {
                    welcomeSeen = true
                    store.openExample()
                })
            }
        }
    }

    private var showing: Binding<Bool> {
        Binding(get: { !welcomeSeen && example != nil }, set: { shown in if !shown { welcomeSeen = true } })
    }
}
