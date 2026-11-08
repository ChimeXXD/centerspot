import SwiftUI

/// Agmen's home (D-56, UI-BRIEF §4.1, mockup "library"): the name and tagline over a faint chalk pitch, the lime
/// New tactic, then the tactics as cards, newest first. Press and hold a card for Rename · Duplicate · Share · Delete.
/// D-74: small wide cards, as many a row as the width allows (`LibraryGrid`): 3 on an iPhone, 6 on a 13-inch iPad in
/// landscape, where New tactic moves to the right of the title (mockup `ipad-library`).
struct LibraryScreen: View {
    let store: LibraryStore

    @State private var renaming: TacticLibrary.Entry?
    @State private var newTitle = ""
    @State private var deleting: TacticLibrary.Entry?
    /// The screen's width, which sets the grid. Until it is known the content stays hidden, so an iPad never shows a
    /// first frame laid out for a phone.
    @State private var width: CGFloat?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                header

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
            .padding(.horizontal, grid.margin)
            .padding(.top, Tokens.Space.s6)
            .padding(.bottom, Tokens.Space.s6)
            .opacity(width == nil ? 0 : 1)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .scrollBounceBehavior(.basedOnSize)
        .background { LaunchBackground(wideFade: grid.isWide ? Self.wideFade : nil) }
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

    private var grid: LibraryGrid {
        LibraryGrid(width: width ?? 0, accessibilityText: dynamicTypeSize.isAccessibilitySize)
    }

    /// The phone's title over a full-width New tactic; on a wide screen New tactic sits at the title's right (stacked
    /// again at the accessibility text sizes, where the title needs the width).
    @ViewBuilder private var header: some View {
        if grid.isWide, !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .bottom, spacing: Tokens.Space.s5) {
                LaunchTitle()
                Spacer(minLength: 0)
                moreMenu
                newTactic.frame(width: Self.wideNewTacticWidth)
            }
            .padding(.bottom, Tokens.Space.s2)
        } else {
            HStack(alignment: .top, spacing: Tokens.Space.s2) {
                LaunchTitle()
                Spacer(minLength: 0)
                moreMenu
            }
            newTactic
        }
    }

    /// Where the chalk pitch behind the title fades on a wide screen (mockup `ipad-library`).
    static let wideFade: ClosedRange<CGFloat> = 96...176

    /// The mockup's New tactic beside the title on a wide screen.
    static let wideNewTacticWidth: CGFloat = 240

    /// More (mockup `library--menu`, D-78): Show tips again replays the welcome and brings every tip back.
    private var moreMenu: some View {
        Menu {
            Button("Show tips again", systemImage: "lightbulb") {
                Task { await Onboarding.shared.showAgain() }
            }
            .accessibilityIdentifier("library.menu.tips")
        } label: {
            Image(systemName: "ellipsis")
                .font(Tokens.Typeface.barIcon)
                .foregroundStyle(Tokens.Colour.text.color)
                .frame(width: Tokens.Size.touch, height: Tokens.Size.touch)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
        .accessibilityIdentifier("library.more")
    }

    private var newTactic: some View {
        Button {
            store.newTactic()
        } label: {
            Label("New tactic", systemImage: "plus")
        }
        .buttonStyle(PrimaryCapsuleStyle())
        .accessibilityIdentifier("launch.new")
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("Recent")
                .font(Tokens.Typeface.headline)
                .foregroundStyle(Tokens.Colour.muted.color)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("library.recent")
            LazyVGrid(columns: columns, alignment: .leading, spacing: grid.rowGap) {
                ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                    card(entry, number: index + 1)
                }
            }
        }
    }

    /// `LibraryGrid`'s count, equal widths.
    private var columns: [GridItem] {
        let grid = grid
        return Array(repeating: GridItem(.flexible(), spacing: grid.columnGap, alignment: .top), count: grid.columns)
    }

    private func card(_ entry: TacticLibrary.Entry, number: Int) -> some View {
        Button {
            store.open(entry.url)
        } label: {
            TacticCard(tactic: entry.tactic, grid: grid)
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
