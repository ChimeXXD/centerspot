import SwiftUI
import UniformTypeIdentifiers

/// CenterSpot's home (D-56, D-89, mockup `library-v2`): your moves first. The last move you opened plays at the top
/// (`ResumeCard`), then every move as a tall upright card. On a phone New tactic floats at the bottom, in reach, and
/// More holds Import, Show tips again and where the files are. From 744 pt wide a sidebar takes New tactic, the
/// All moves · This week · Earlier filters and those extras (`LibrarySidebar`), and the moves can show as a grid or a
/// list. Press and hold a move for Rename · Duplicate · Share · Delete.
struct LibraryScreen: View {
    let store: LibraryStore

    @State private var renaming: TacticLibrary.Entry?
    @State private var newTitle = ""
    @State private var deleting: TacticLibrary.Entry?
    @State private var importing = false
    @State private var query = LibraryQuery()
    @AppStorage(Self.showsListKey) private var showsList = false
    /// The screen's width, which sets the layout. Until it is known the content stays hidden, so an iPad never shows a
    /// first frame laid out for a phone.
    @State private var width: CGFloat?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if grid.isWide { wide } else { compact }
        }
        .opacity(width == nil ? 0 : 1)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background(Tokens.Colour.bg.color)
        // Hidden here, but it names the board's back button.
        .navigationTitle("CenterSpot")
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { store.refresh() }
        // Files may have changed in the Files app while CenterSpot was away.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refresh() }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.tactic]) { result in
            guard case .success(let url) = result else {
                store.alert = LibraryStore.failedMessage
                return
            }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            store.importAndOpen(url)
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

    // MARK: Layouts

    /// The phone: the name and More, then the moves scrolling under a floating New tactic.
    private var compact: some View {
        VStack(spacing: 0) {
            HStack {
                BrandLockup()
                Spacer(minLength: 0)
                moreMenu
            }
            .padding(.leading, grid.margin)
            .padding(.trailing, Tokens.Space.s2)
            .frame(height: Self.topBarHeight)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    resume
                    sectionHeader("Your moves", count: store.entries.count)
                    // Sorted only: the sidebar's filters belong to the wide layout, so one picked there before the
                    // window narrowed never hides moves here.
                    moves(LibraryQuery(sort: query.sort).apply(to: store.entries))
                    hints
                }
                .padding(.horizontal, grid.margin)
                .padding(.bottom, Self.floatingClearance)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .overlay(alignment: .bottom) { floatingNew }
    }

    /// From 744 pt: the sidebar, then the filtered moves with the last one playing on top of All moves.
    private var wide: some View {
        HStack(spacing: 0) {
            LibrarySidebar(
                counts: Dictionary(uniqueKeysWithValues: LibraryQuery.Filter.allCases.map { ($0, LibraryQuery.count($0, in: store.entries)) }),
                filter: query.filter, skipped: store.skipped,
                onFilter: { query.filter = $0 }, onNew: { store.newTactic() }, onImport: { importing = true },
                onTips: { Task { await Onboarding.shared.showAgain() } }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: Tokens.Space.s3) {
                        Text(query.filter.title)
                            .font(Tokens.Typeface.largeTitle)
                            .foregroundStyle(Tokens.Colour.text.color)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 0)
                        sortMenu
                        viewSwitch
                    }
                    .frame(minHeight: Tokens.Size.touch)
                    .padding(.bottom, Tokens.Space.s5)
                    if query.filter == .all { resume }
                    let shown = query.apply(to: store.entries)
                    if query.filter == .all { sectionHeader("Every move", count: shown.count, sorts: false) }
                    if shown.isEmpty, !store.entries.isEmpty {
                        Text(query.filter == .thisWeek ? "Nothing edited in the last seven days." : "Every move was edited this week.")
                            .font(Tokens.Typeface.body)
                            .foregroundStyle(Tokens.Colour.muted.color)
                            .accessibilityIdentifier("library.filter-empty")
                    } else {
                        moves(shown)
                    }
                    if store.entries.isEmpty || store.onlyExample { emptyHint.padding(.top, Tokens.Space.s5) }
                }
                .padding(.horizontal, grid.margin)
                .padding(.top, Tokens.Space.s5)
                .padding(.bottom, Tokens.Space.s6)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: Parts

    private var grid: LibraryGrid {
        LibraryGrid(width: width ?? 0, accessibilityText: dynamicTypeSize.isAccessibilitySize)
    }

    static let topBarHeight: CGFloat = 52
    /// Grid or List on the wide layout, kept across launches.
    nonisolated static let showsListKey = "library.list"
    /// Room under the last row for the floating New tactic.
    static let floatingClearance: CGFloat = 120

    /// The last move you opened (or the newest), playing.
    @ViewBuilder private var resume: some View {
        if let entry = store.resumeEntry {
            ResumeCard(entry: entry, badge: badge(for: entry), wide: grid.isWide,
                       isActive: store.path.isEmpty && scenePhase == .active,
                       onOpen: { store.open(entry.url) }, onExport: { store.open(entry.url, opensExport: true) })
        }
    }

    /// "Example" while it is the only move, "Last opened" once you've opened one, else "Latest".
    private func badge(for entry: TacticLibrary.Entry) -> String {
        if store.onlyExample { return "Example" }
        return store.lastOpenedEntry == entry ? "Last opened" : "Latest"
    }

    private func sectionHeader(_ title: String, count: Int, sorts: Bool = true) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
            Text(title)
                .font(Tokens.Typeface.headline)
                .foregroundStyle(Tokens.Colour.text.color)
                .accessibilityAddTraits(.isHeader)
            Text("\(count)")
                .font(Tokens.Typeface.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Tokens.Colour.muted.color)
                .accessibilityLabel(count == 1 ? "1 move" : "\(count) moves")
                .accessibilityIdentifier("library.count")
            Spacer(minLength: 0)
            if sorts { sortMenu }
        }
        .padding(.top, Tokens.Space.s5)
        .padding(.bottom, Tokens.Space.s3)
    }

    /// The moves (already filtered and sorted) as tall cards, or rows in the wide layout's list.
    @ViewBuilder private func moves(_ entries: [TacticLibrary.Entry]) -> some View {
        let actions = itemActions
        let look: LibraryItem.Look = grid.isWide && showsList ? .row : .card
        let columns = Array(repeating: GridItem(.flexible(), spacing: grid.columnGap, alignment: .top),
                            count: look == .row ? 1 : grid.columns)
        LazyVGrid(columns: columns, alignment: .leading, spacing: look == .row ? Tokens.Space.s2 : grid.rowGap) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { @Sendable index, entry in
                LibraryItem(entry: entry, number: index + 1, look: look, actions: actions)
            }
        }
    }

    private var itemActions: LibraryItemActions {
        LibraryItemActions(
            open: { store.open($0.url) },
            rename: { newTitle = $0.tactic.title; renaming = $0 },
            duplicate: { store.duplicate($0) },
            delete: { deleting = $0 }
        )
    }

    /// The phone's notes under the grid: what to do when only the example is here, and unreadable files.
    @ViewBuilder private var hints: some View {
        if store.entries.isEmpty || store.onlyExample { emptyHint.padding(.top, Tokens.Space.s5) }
        if store.skipped > 0 {
            Text(Self.skippedText(store.skipped))
                .font(Tokens.Typeface.caption)
                .foregroundStyle(Tokens.Colour.muted.color)
                .padding(.top, Tokens.Space.s4)
                .accessibilityIdentifier("library.skipped")
        }
    }

    private var emptyHint: some View {
        VStack(spacing: Tokens.Space.s3) {
            Text("Your moves will show here. Start one with New tactic, or open the example to see how it's made.")
                .font(Tokens.Typeface.body)
                .foregroundStyle(Tokens.Colour.muted.color)
                .multilineTextAlignment(.center)
            if store.entries.isEmpty {
                Button("Open the example") { store.openExample() }
                    .buttonStyle(RowCapsuleStyle())
                    .accessibilityIdentifier("library.example")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Tokens.Space.s5)
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sheet).strokeBorder(Tokens.Colour.hairline.color, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library.empty")
    }

    /// New tactic over the bottom of the moves, with the page fading out behind it.
    private var floatingNew: some View {
        Button { store.newTactic() } label: {
            Label("New tactic", systemImage: "plus")
                .font(Tokens.Typeface.headline.weight(.bold))
                .foregroundStyle(Tokens.Colour.accentInk.color)
                .padding(.horizontal, Tokens.Space.s5)
                .frame(minHeight: Tokens.Size.capsule)
                .background(Tokens.Colour.accent.color, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("launch.new")
        .padding(.top, Tokens.Space.s6)
        .padding(.bottom, Tokens.Space.s2)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: [Tokens.Colour.bg.color.opacity(0), Tokens.Colour.bg.color], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    /// More (D-78): Import, Show tips again (replays the welcome and brings every tip back), and where the files are.
    private var moreMenu: some View {
        Menu {
            Button("Import a .tactic file", systemImage: "square.and.arrow.down") { importing = true }
                .accessibilityIdentifier("library.menu.import")
            Button("Show tips again", systemImage: "lightbulb") {
                Task { await Onboarding.shared.showAgain() }
            }
            .accessibilityIdentifier("library.menu.tips")
            Section { Text(Self.whereSaved) }
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

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $query.sort) {
                ForEach(LibraryQuery.Sort.allCases) { Text($0.title).tag($0) }
            }
        } label: {
            HStack(spacing: Tokens.Space.s1) {
                Text(query.sort.title)
                Image(systemName: "chevron.down").font(Tokens.Typeface.caption.weight(.bold))
            }
            .font(Tokens.Typeface.caption.weight(.semibold))
            .foregroundStyle(Tokens.Colour.muted.color)
            .padding(.horizontal, Tokens.Space.s3)
            .frame(minHeight: 32)
            .background(Tokens.Colour.surface2.color, in: Capsule())
            .frame(minHeight: Tokens.Size.touch)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Sort")
        .accessibilityValue(query.sort.title)
        .accessibilityIdentifier("library.sort")
    }

    /// Grid or list, on the wide layout.
    private var viewSwitch: some View {
        CapsuleSegments(options: [
            .init(value: false, title: "Grid", identifier: "library.view.grid"),
            .init(value: true, title: "List", identifier: "library.view.list"),
        ], selection: $showsList)
        .frame(width: 160)
    }

    /// Where the files are, in the words Files uses on this device.
    static var whereSaved: String {
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        return "Saved on this \(device). Find them in Files › On My \(device) › CenterSpot."
    }

    static func skippedText(_ count: Int) -> String {
        count == 1 ? "1 file in the folder can't be opened." : "\(count) files in the folder can't be opened."
    }

    private func isPresent<T>(_ item: Binding<T?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}
