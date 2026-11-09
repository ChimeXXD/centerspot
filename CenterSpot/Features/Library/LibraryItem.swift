import SwiftUI

/// What a library item can do: open, and press and hold for Rename · Duplicate · Share · Delete.
struct LibraryItemActions: Sendable {
    let open: @MainActor (TacticLibrary.Entry) -> Void
    let rename: @MainActor (TacticLibrary.Entry) -> Void
    let duplicate: @MainActor (TacticLibrary.Entry) -> Void
    let delete: @MainActor (TacticLibrary.Entry) -> Void
}

/// One move in the library, as a tall card (the grid) or a row (the iPad's list, D-89). Built from plain values with
/// a `nonisolated` init, so a `@Sendable` `ForEach` can make it on SwiftUI's render thread (the iPad crash, 8 Nov).
/// VoiceOver reads "<title>, 5 steps" with "8 seconds, edited today" as its value.
struct LibraryItem: View {
    enum Look: Sendable { case card, row }

    let entry: TacticLibrary.Entry
    let number: Int
    let look: Look
    let actions: LibraryItemActions

    nonisolated init(entry: TacticLibrary.Entry, number: Int, look: Look, actions: LibraryItemActions) {
        self.entry = entry
        self.number = number
        self.look = look
        self.actions = actions
    }

    var body: some View {
        Button { actions.open(entry) } label: {
            switch look {
            case .card: TacticCard(tactic: entry.tactic, modified: entry.modified)
            case .row: LibraryRow(tactic: entry.tactic, modified: entry.modified)
            }
        }
        .buttonStyle(.plain)
        .contextMenu { menu }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.tactic.title), \(LibraryFormat.steps(entry.tactic))")
        .accessibilityValue(spokenValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityActions { menu }
        .accessibilityIdentifier("library.card.\(number)")
    }

    /// "8 seconds, edited today"; a move with nothing to play says only when it was edited.
    private var spokenValue: String {
        let length = LibraryFormat.length(of: entry.tactic), edited = "edited \(LibraryFormat.editedInSentence(entry.modified))"
        return LibraryFormat.plays(length) ? "\(LibraryFormat.spokenLength(length)), \(edited)" : edited
    }

    @ViewBuilder private var menu: some View {
        Button("Rename", systemImage: "pencil") { actions.rename(entry) }
        Button("Duplicate", systemImage: "plus.square.on.square") { actions.duplicate(entry) }
        ShareLink(item: entry.url, preview: SharePreview(entry.tactic.title)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        Button("Delete", systemImage: "trash", role: .destructive) { actions.delete(entry) }
    }
}

/// A move in the iPad's list: a small upright pitch, the name and "5 steps · Today", the length at the end.
private struct LibraryRow: View {
    let tactic: Tactic
    let modified: Date

    static let thumbnailWidth: CGFloat = 44

    var body: some View {
        HStack(spacing: Tokens.Space.s3) {
            CardThumbnail(tactic: tactic)
                .aspectRatio(TacticCard.aspect, contentMode: .fit)
                .frame(width: Self.thumbnailWidth)
                .background(Tokens.Colour.bcPitchA.color)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(tactic.title)
                    .font(Tokens.Typeface.cardTitle)
                    .foregroundStyle(Tokens.Colour.text.color)
                    .lineLimit(1)
                Text("\(LibraryFormat.steps(tactic)) · \(LibraryFormat.edited(modified))")
                    .font(Tokens.Typeface.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Colour.muted.color)
            }
            Spacer(minLength: Tokens.Space.s2)
            let length = LibraryFormat.length(of: tactic)
            if LibraryFormat.plays(length) {
                Text(LibraryFormat.clock(length))
                    .font(Tokens.Typeface.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Colour.muted.color)
            }
        }
        .padding(Tokens.Space.s2)
        .background(Tokens.Colour.surface.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.item))
        .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.item))
    }
}
