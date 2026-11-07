import SwiftUI

/// One tactic in the library grid (mockup "library"): step 1 at rest, drawn by the board's own renderer (D-07),
/// then the title and "11-a-side · 5 steps".
struct TacticCard: View {
    let tactic: Tactic

    /// Every card uses the full pitch's shape so the grid lines up; smaller pitches are centred inside it.
    static let aspect = CGFloat(Pitch.Kind.full.size.width / Pitch.Kind.full.size.length)

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Canvas { context, size in
                let state = Timeline.restingState(step: 0, in: tactic)
                context.withCGContext { cg in
                    BoardRenderer.draw(state: state, tactic: tactic, in: cg, rect: CGRect(origin: .zero, size: size))
                }
            }
            .aspectRatio(Self.aspect, contentMode: .fit)
            .padding(.bottom, Tokens.Space.s2)

            Text(tactic.title)
                .font(Tokens.Typeface.headline.weight(.heavy))
                .foregroundStyle(Tokens.Colour.text.color)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text("\(Self.pitchName(tactic.pitch.kind)) · \(Self.steps(tactic))")
                .font(Tokens.Typeface.caption)
                .foregroundStyle(Tokens.Colour.muted.color)
        }
        .padding(Tokens.Space.s3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
        .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.tile))
    }

    /// "1 step", "5 steps" (the main phase, as on the board).
    static func steps(_ tactic: Tactic) -> String {
        let count = tactic.phases.first?.steps.count ?? 0
        return count == 1 ? "1 step" : "\(count) steps"
    }

    static func pitchName(_ kind: Pitch.Kind) -> String {
        switch kind {
        case .full: "11-a-side"
        case .sevenASide: "7-a-side"
        case .fiveASide: "5-a-side"
        }
    }
}
