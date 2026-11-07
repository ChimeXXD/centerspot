import SwiftUI

/// The launch screen's background (UI-BRIEF §4.1, mockup "library"): the Floodlight dark with a faint chalk pitch
/// fragment, drawn by the same `BoardRenderer` as the board (D-07).
struct LaunchBackground: View {
    /// The pitch fragment's strength behind the title: the opponent's box and the centre circle, fading out.
    static let opacity = 0.6

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = BoardGeometry.height(forWidth: width, kind: .full)
            Canvas { context, size in
                let tactic = TacticDocument.blank(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
                let state = BoardState(positions: [:], arrows: [], stepIndex: 0)
                context.withCGContext { cg in
                    BoardRenderer.draw(state: state, tactic: tactic, in: cg, rect: CGRect(origin: .zero, size: size))
                }
            }
            .frame(width: width, height: height)
            .opacity(Self.opacity)
            .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
            .frame(maxHeight: .infinity, alignment: .top)
            .offset(y: proxy.safeAreaInsets.top - height * 0.12)
            .accessibilityHidden(true)
        }
        .background(Tokens.Colour.bg.color.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            // Sits where the system title would, above the New tactic button the scene places.
            LaunchTitle()
                .padding(.horizontal, Tokens.Space.s5)
                .padding(.top, Tokens.Space.s6 + Tokens.Space.s5)
        }
    }
}

/// "Agmen" in heavy Nunito with the tagline under it, as in the mockup's library frame.
struct LaunchTitle: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Text("Agmen")
                .font(Tokens.Typeface.largeTitle)
                .foregroundStyle(Tokens.Colour.text.color)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("library.title")
            LaunchTagline()
        }
    }
}

/// The handwritten tagline under the app name (UI-BRIEF §1 rule 5: Kalam is the coach's voice).
struct LaunchTagline: View {
    var body: some View {
        Text("Draw the move, not just the shape.")
            .font(Tokens.Typeface.note)
            .foregroundStyle(Tokens.Colour.muted.color)
            .accessibilityIdentifier("library.tagline")
    }
}
