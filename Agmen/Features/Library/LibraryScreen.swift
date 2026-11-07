import SwiftUI

/// Agmen's home (D-56, UI-BRIEF §4.1, mockup "library"): the name and tagline over a faint chalk pitch, the lime
/// New tactic, then the tactics as cards, newest first. Press and hold a card for Rename · Duplicate · Share · Delete.
struct LibraryScreen: View {
    let store: LibraryStore

    @State private var renaming: TacticLibrary.Entry?
    @State private var newTitle = ""
    @State private var deleting: TacticLibrary.Entry?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                LaunchTitle()
                Button {
                    store.newTactic()
                } label: {
                    Label("New tactic", systemImage: "plus")
                }
                .buttonStyle(PrimaryCapsuleStyle())
                .accessibilityIdentifier("launch.new")

                if store.entries.isEmpty {
                    Text("Your tactics show up here.")
                        .font(Tokens.Typeface.body)
                        .foregroundStyle(Tokens.Colour.muted.color)
                        .accessibilityIdentifier("library.empty")
                } else {
                    recent
                }
                footer
            }
            .padding(.horizontal, Tokens.Space.s5)
            .padding(.top, Tokens.Space.s6)
            .padding(.bottom, Tokens.Space.s6)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background { LaunchBackground() }
        // Hidden here, but it names the board's back button.
        .navigationTitle("Agmen")
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { store.refresh() }
        // Files may have changed in the Files app while Agmen was away.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refresh() }
        }
        .alert("Rename tactic", isPresented: isPresent($renaming), presenting: renaming) { entry in
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { store.rename(entry, to: newTitle) }
                .accessibilityIdentifier("library.rename.save")
        }
        .confirmationDialog(
            deleting.map { "Delete “\($0.tactic.title)”?" } ?? "",
            isPresented: isPresent($deleting), titleVisibility: .visible, presenting: deleting
        ) { entry in
            Button("Delete", role: .destructive) { store.delete(entry) }
                .accessibilityIdentifier("library.delete.confirm")
        } message: { _ in
            Text("This can't be undone.")
        }
    }

    // MARK: Parts

    private var recent: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("Recent")
                .font(Tokens.Typeface.headline)
                .foregroundStyle(Tokens.Colour.muted.color)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("library.recent")
            LazyVGrid(columns: columns, alignment: .leading, spacing: Tokens.Space.s4) {
                ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                    card(entry, number: index + 1)
                }
            }
        }
    }

    /// Two columns, or one at the accessibility text sizes so titles stay readable.
    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s4, alignment: .top), count: count)
    }

    private func card(_ entry: TacticLibrary.Entry, number: Int) -> some View {
        Button {
            store.open(entry.url)
        } label: {
            TacticCard(tactic: entry.tactic)
        }
        .buttonStyle(.plain)
        .contextMenu { actions(entry) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.tactic.title), \(TacticCard.steps(entry.tactic))")
        .accessibilityAddTraits(.isButton)
        .accessibilityActions { actions(entry) }
        .accessibilityIdentifier("library.card.\(number)")
    }

    @ViewBuilder private func actions(_ entry: TacticLibrary.Entry) -> some View {
        Button("Rename", systemImage: "pencil") {
            newTitle = entry.tactic.title
            renaming = entry
        }
        Button("Duplicate", systemImage: "plus.square.on.square") { store.duplicate(entry) }
        ShareLink(item: entry.url, preview: SharePreview(entry.tactic.title)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        Button("Delete", systemImage: "trash", role: .destructive) { deleting = entry }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Text(Self.whereSaved)
                .accessibilityIdentifier("library.recents-hint")
            if store.skipped > 0 {
                Text(store.skipped == 1 ? "1 file in the folder can't be opened." : "\(store.skipped) files in the folder can't be opened.")
                    .accessibilityIdentifier("library.skipped")
            }
        }
        .font(Tokens.Typeface.caption)
        .foregroundStyle(Tokens.Colour.muted.color)
    }

    /// Where the files are, in the words Files uses on this device.
    static var whereSaved: String {
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        return "Saved on this \(device). Find them in Files › On My \(device) › Agmen."
    }

    private func isPresent<T>(_ item: Binding<T?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}
