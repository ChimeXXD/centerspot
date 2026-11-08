import SwiftUI
import TipKit

/// The tips' face (mockup `tip-*--bc`): the title in the headline face, one muted line, and a close button that ends
/// the tip (D-58: × closes it and the next one can come). TipKit draws the popover and its arrow on `surface3`.
struct AgmenTipStyle: TipViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.s1) {
            VStack(alignment: .leading, spacing: 2) {
                configuration.title?
                    .font(Tokens.Typeface.headline)
                    .foregroundStyle(Tokens.Colour.text.color)
                configuration.message?
                    .font(Tokens.Typeface.body)
                    .foregroundStyle(Tokens.Colour.muted.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
            Button {
                configuration.tip.invalidate(reason: .tipClosed)
            } label: {
                Image(systemName: "xmark")
                    .font(Tokens.Typeface.inlineIcon)
                    .foregroundStyle(Tokens.Colour.muted.color)
                    .frame(width: Tokens.Size.touch, height: Tokens.Size.touch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, -Tokens.Space.s2)
            .accessibilityLabel("Close tip")
            .accessibilityIdentifier("tip.close")
        }
        .padding(.leading, Tokens.Space.s4)
        .padding(.trailing, Tokens.Space.s1)
        .padding(.vertical, Tokens.Space.s3)
    }
}

extension View {
    /// A tip from `Onboarding` in the app's tip look, pointing at this control. The screen behind it stays live, so the
    /// first tap on Play plays (instead of only closing the tip), and that is what finishes the tip.
    /// Only a control with a tip due carries TipKit's popover at all: the modifier on every token stopped the board
    /// rendering offscreen (`RendererParityTests`) and took taps in Draw mode.
    @ViewBuilder func agmenTip(_ tip: (any Tip)?, arrowEdge: Edge) -> some View {
        if let tip {
            popoverTip(tip, arrowEdge: arrowEdge)
                .tipViewStyle(AgmenTipStyle())
                .tipBackground(Tokens.Colour.surface3.color)
                .tipBackgroundInteraction(.enabled)
        } else {
            self
        }
    }
}
