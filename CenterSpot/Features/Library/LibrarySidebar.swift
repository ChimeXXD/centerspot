import SwiftUI

/// The wide library's sidebar (D-89, mockup `library-v2--ipad`): the mark and name, New tactic, All moves · This week ·
/// Earlier with their counts, and at the foot Import, Show tips again and where the files are.
struct LibrarySidebar: View {
    let counts: [LibraryQuery.Filter: Int]
    let filter: LibraryQuery.Filter
    let skipped: Int
    let onFilter: @MainActor (LibraryQuery.Filter) -> Void
    let onNew: @MainActor () -> Void
    let onImport: @MainActor () -> Void
    let onTips: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            BrandLockup(markSize: 32)
                .padding(.horizontal, Tokens.Space.s2)
                .frame(height: Tokens.Size.touch)
                .padding(.bottom, Tokens.Space.s3)
            Button(action: onNew) { Label("New tactic", systemImage: "plus") }
                .buttonStyle(PrimaryCapsuleStyle())
                .accessibilityIdentifier("launch.new")
                .padding(.bottom, Tokens.Space.s4)
            ForEach(LibraryQuery.Filter.allCases) { item in
                row(item.title, trailing: Text("\(counts[item] ?? 0)").monospacedDigit(), on: item == filter) { onFilter(item) }
                    .accessibilityValue("\(counts[item] ?? 0) moves")
                    .accessibilityAddTraits(item == filter ? .isSelected : [])
                    .accessibilityIdentifier("library.filter.\(item.rawValue)")
            }
            Spacer(minLength: Tokens.Space.s5)
            row("Import a .tactic file", trailing: Image(systemName: "square.and.arrow.down"), action: onImport)
                .accessibilityIdentifier("library.menu.import")
            row("Show tips again", trailing: Image(systemName: "lightbulb"), action: onTips)
                .accessibilityIdentifier("library.menu.tips")
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                Text(LibraryScreen.whereSaved)
                    .accessibilityIdentifier("library.recents-hint")
                if skipped > 0 {
                    Text(LibraryScreen.skippedText(skipped))
                        .accessibilityIdentifier("library.skipped")
                }
            }
            .font(Tokens.Typeface.caption)
            .foregroundStyle(Tokens.Colour.muted.color)
            .padding(.horizontal, Tokens.Space.s3)
            .padding(.top, Tokens.Space.s2)
        }
        .padding(EdgeInsets(top: Tokens.Space.s5, leading: Tokens.Space.s4, bottom: Tokens.Space.s5, trailing: Tokens.Space.s4))
        .frame(width: LibraryGrid.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Tokens.Colour.hairline.color).frame(width: 1)
        }
    }

    /// A 40 pt row: the label, and a count or an icon at the end; lit when it's the current filter.
    private func row(_ title: String, trailing: some View, on: Bool = false,
                     action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(Tokens.Typeface.body.weight(.semibold))
                Spacer(minLength: Tokens.Space.s2)
                trailing.font(Tokens.Typeface.caption.weight(.semibold)).foregroundStyle(Tokens.Colour.muted.color)
            }
            .foregroundStyle(on ? Tokens.Colour.text.color : Tokens.Colour.muted.color)
            .padding(.horizontal, Tokens.Space.s3)
            .frame(minHeight: Tokens.Size.touch)
            .background(on ? Tokens.Colour.surface2.color : .clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
