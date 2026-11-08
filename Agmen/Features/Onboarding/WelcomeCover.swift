import SwiftUI

/// Shows the welcome over the library until it has been seen (D-58): on first launch, and after Show tips again. Skip
/// lands on the library; Start opens the example move. Without the bundled example there is nothing to show, so it
/// counts as seen.
struct WelcomeCover: ViewModifier {
    let store: LibraryStore
    @AppStorage(Onboarding.welcomeSeenKey) private var welcomeSeen = false

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

    private var example: Tactic? {
        store.library.exampleURL.flatMap { try? store.library.load($0) }
    }

    private var showing: Binding<Bool> {
        Binding(get: { !welcomeSeen && example != nil }, set: { shown in if !shown { welcomeSeen = true } })
    }
}
