import SwiftUI

/// One move in the library (D-89, mockup `library-v2`): step 1 at rest on an upright pitch, the shape of the 9:16 video,
/// drawn by the board's own renderer (D-07, `CardStyle.upright`), with the move's length on it ("0:08"); then the name
/// (two lines at most) and "5 steps · Today".
struct TacticCard: View {
    let tactic: Tactic
    let modified: Date

    /// Every card uses the full pitch's upright shape, so the grid lines up; smaller pitches sit centred in it.
    static let aspect = CGFloat(Pitch.Kind.full.size.width / Pitch.Kind.full.size.length)

    nonisolated init(tactic: Tactic, modified: Date) {
        self.tactic = tactic
        self.modified = modified
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            CardThumbnail(tactic: tactic)
                .aspectRatio(Self.aspect, contentMode: .fit)
                .background(Tokens.Colour.bcPitchA.color)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.item))
                .overlay(alignment: .bottomTrailing) {
                    let length = LibraryFormat.length(of: tactic)
                    if LibraryFormat.plays(length) { LengthBadge(seconds: length) }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(tactic.title)
                    .font(Tokens.Typeface.cardTitle)
                    .foregroundStyle(Tokens.Colour.text.color)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(LibraryFormat.steps(tactic)) · \(LibraryFormat.edited(modified))")
                    .font(Tokens.Typeface.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Colour.muted.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }
}

/// "0:08" on a card's picture, as on a video.
struct LengthBadge: View {
    let seconds: Double

    var body: some View {
        Text(LibraryFormat.clock(seconds))
            .font(Tokens.Typeface.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(Tokens.Colour.text.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Tokens.Colour.bg.color.opacity(0.78), in: RoundedRectangle(cornerRadius: 6))
            .padding(Tokens.Space.s2)
            .accessibilityHidden(true)
    }
}

/// Step 1 at rest, upright, through `Canvas` and `withCGContext` like the board (D-07). Drawing a card takes about
/// 1 ms (measured in `CardThumbnailTests`), and `Canvas` keeps its drawing until the tactic or size changes.
struct CardThumbnail: View {
    let tactic: Tactic

    var body: some View {
        Canvas { context, size in
            let state = Timeline.restingState(step: 0, in: tactic)
            context.withCGContext { cg in
                BoardRenderer.draw(state: state, tactic: tactic, in: cg, rect: CGRect(origin: .zero, size: size),
                                   options: .init(card: .upright))
            }
        }
        .accessibilityHidden(true)
    }
}
