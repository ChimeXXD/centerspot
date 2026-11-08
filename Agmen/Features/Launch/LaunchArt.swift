import SwiftUI

/// The library's background (UI-BRIEF §4.1, mockup "library"): the Floodlight dark with a faint chalk pitch
/// fragment, drawn by the same `BoardRenderer` as the board (D-07).
struct LaunchBackground: View {
    /// The pitch fragment's strength behind the title: the opponent's box, fading out.
    static let opacity = 0.6
    /// Gone before the centre circle starts (about 0.41 of the pitch), so no stray arc shows beside the cards.
    static let fadeEnd = 0.38
    /// On a wide screen the pitch is far taller than the header, so the fade is set in points from the top of the
    /// screen instead: whole down to the first, gone by the second (mockup `ipad-library`: 96 to 176 pt, D-74).
    var wideFade: ClosedRange<CGFloat>?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = BoardGeometry.height(forWidth: width, kind: .full)
            let top = proxy.safeAreaInsets.top - height * 0.12
            Canvas { context, size in
                let tactic = TacticDocument.blank(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
                let state = BoardState(positions: [:], arrows: [], stepIndex: 0)
                context.withCGContext { cg in
                    BoardRenderer.draw(state: state, tactic: tactic, in: cg, rect: CGRect(origin: .zero, size: size))
                }
            }
            .frame(width: width, height: height)
            .opacity(Self.opacity)
            .mask(LinearGradient(stops: fadeStops(height: height, top: top, safeTop: proxy.safeAreaInsets.top),
                                 startPoint: .top, endPoint: .bottom))
            .frame(maxHeight: .infinity, alignment: .top)
            .offset(y: top)
            .accessibilityHidden(true)
        }
        .background(Tokens.Colour.bg.color.ignoresSafeArea())
    }

    /// The mask's stops along the pitch, which starts `top` points below the safe area's top (`safeTop` below the
    /// screen's, where the mockup measures from).
    private func fadeStops(height: CGFloat, top: CGFloat, safeTop: CGFloat) -> [Gradient.Stop] {
        guard let wideFade, height > 0 else {
            return [.init(color: .black, location: 0), .init(color: .clear, location: Self.fadeEnd)]
        }
        let start = (wideFade.lowerBound - safeTop - top) / height, end = (wideFade.upperBound - safeTop - top) / height
        return [.init(color: .black, location: start), .init(color: .clear, location: end)]
    }
}

/// "Agmen" in heavy Nunito with the tagline under it, as in the mockup's library frame.
struct LaunchTitle: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Text("Agmen")
                .font(Tokens.Typeface.wordmark)
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
