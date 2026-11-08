import SwiftUI

/// One tactic in the library grid (D-74, mockup `library--compact` and `ipad-library`): step 1 at rest with the
/// whole pitch turned sideways, drawn by the board's own renderer (D-07, `CardStyle`), then the name (two lines at
/// most) and "5 steps". Sizes come from the grid, so a wide iPad card gets the mockup's bigger type and padding.
struct TacticCard: View {
    let tactic: Tactic
    let grid: LibraryGrid

    /// Every card uses the full pitch's shape, turned sideways, so the grid lines up; smaller pitches sit centred in it.
    static let aspect = CGFloat(Pitch.Kind.full.size.length / Pitch.Kind.full.size.width)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnail
            Text(tactic.title)
                .font(grid.nameFont)
                .foregroundStyle(Tokens.Colour.text.color)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .padding(.top, grid.nameGap)
            Text(Self.steps(tactic))
                .font(grid.metaFont)
                .foregroundStyle(Tokens.Colour.muted.color)
                .padding(.top, LibraryGrid.metaGap)
        }
        .padding([.horizontal, .top], grid.inset)
        .padding(.bottom, grid.bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: grid.cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: grid.cornerRadius))
    }

    private var thumbnail: some View {
        CardThumbnail(tactic: tactic)
            .aspectRatio(Self.aspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: LibraryGrid.thumbnailCorner))
    }

    /// "1 step", "5 steps" (the main phase, as on the board).
    static func steps(_ tactic: Tactic) -> String {
        let count = tactic.phases.first?.steps.count ?? 0
        return count == 1 ? "1 step" : "\(count) steps"
    }
}

/// Step 1 at rest, sideways, through `Canvas` and `withCGContext` like the board (D-07). Drawing a card takes about
/// 1 ms (measured in `CardThumbnailTests`), and `Canvas` keeps its drawing until the tactic or size changes.
struct CardThumbnail: View {
    let tactic: Tactic

    var body: some View {
        Canvas { context, size in
            let state = Timeline.restingState(step: 0, in: tactic)
            context.withCGContext { cg in
                BoardRenderer.draw(state: state, tactic: tactic, in: cg, rect: CGRect(origin: .zero, size: size),
                                   options: .init(card: .card))
            }
        }
        .accessibilityHidden(true)
    }
}
