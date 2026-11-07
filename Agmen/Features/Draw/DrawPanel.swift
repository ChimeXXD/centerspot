import SwiftUI

/// Under the pitch in draw mode (the mockup's "draw" screen): the handwritten hint, then a panel with the picked kind's
/// help line and the four kinds. The kind decides what a stroke from a player moves (D-59); each tile draws its line
/// style in its colour, so kinds never differ by colour alone (D-15).
struct DrawPanel: View {
    @Binding var kind: Arrow.Kind
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Four tiles in a row, or two by two at the accessibility sizes so "Dribble" fits (D6-3).
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s1 + 2),
              count: dynamicTypeSize.isAccessibilitySize ? 2 : 4)
    }

    var body: some View {
        VStack(spacing: 0) {
            // At the accessibility sizes the hint would push the pitch down to a thumbnail, so it's left out and the
            // pitch keeps the room (D-68). The help line below names the kind's line, not where to start.
            if !dynamicTypeSize.isAccessibilitySize {
                Text("Start on a player to draw their \(Self.noun(kind)).")
                    .font(Tokens.Typeface.note)
                    .foregroundStyle(Tokens.Colour.muted.color)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.s5)
                    .padding(.top, Tokens.Space.s3)
                    .accessibilityIdentifier("draw.hint")
                    .padding(.bottom, Tokens.Space.s5)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text(Self.help(kind))
                    .font(Tokens.Typeface.caption)
                    .foregroundStyle(Tokens.Colour.muted.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Tokens.Space.s1 + 2)
                    .accessibilityIdentifier("draw.kind-help")
                LazyVGrid(columns: columns, spacing: Tokens.Space.s1 + 2) {
                    ForEach(Arrow.Kind.allCases, id: \.self) { tile($0) }
                }
            }
            .padding(.horizontal, Tokens.Space.s3)
            .padding(.vertical, Tokens.Space.s2 + 2)
            .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.panel))
            .shadow(color: .black.opacity(0.5), radius: 15, y: 8)
            .padding(.horizontal, Tokens.Space.s4)
            .padding(.top, dynamicTypeSize.isAccessibilitySize ? Tokens.Space.s3 : 0)
            .padding(.bottom, Tokens.Space.s2)
        }
    }

    private func tile(_ option: Arrow.Kind) -> some View {
        let on = option == kind
        return Button { kind = option } label: {
            VStack(spacing: Tokens.Space.s1 + 2) {
                KindIcon(kind: option)
                    .frame(width: 40, height: 24)
                Text(Self.title(option))
                    .font(Tokens.Typeface.body.weight(.bold))
                    .foregroundStyle(Tokens.Colour.text.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.kindTile)
            .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.tile)
                    .strokeBorder(on ? Tokens.Colour.accent.color : .clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.tile))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.title(option))
        .accessibilityHint(Self.help(option))
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("draw.kind.\(option.rawValue)")
    }

    static func title(_ kind: Arrow.Kind) -> String {
        switch kind {
        case .run: "Run"
        case .pass: "Pass"
        case .dribble: "Dribble"
        case .press: "Press"
        }
    }

    static func noun(_ kind: Arrow.Kind) -> String { title(kind).lowercased() }

    /// What a stroke of this kind does (D-59). Run's line is the mockup's; the others follow its pattern.
    static func help(_ kind: Arrow.Kind) -> String {
        switch kind {
        case .run: "Run · solid line · the player follows it"
        case .pass: "Pass · dashed line · the ball follows it"
        case .dribble: "Dribble · wavy line · player and ball follow it"
        case .press: "Press · chevrons · the player closes in"
        }
    }
}

/// The kind's line style in its colour, as the mockup's tile icons draw it (24 × 24 view box, stretched to the frame).
private struct KindIcon: View {
    let kind: Arrow.Kind

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 24, sy = size.height / 24
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
            var line = SwiftUI.Path()
            var style = StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
            switch kind {
            case .run:
                line.addLines([p(3, 12), p(21, 12)])
            case .pass:
                line.addLines([p(3, 12), p(21, 12)])
                style.dash = [4 * sx, 3 * sx]
            case .dribble:
                line.addLines([p(3, 12), p(6, 9), p(9, 15), p(12, 9), p(15, 15), p(18, 9), p(21, 12)])
                style.lineWidth = 2.2
            case .press:
                line.addLines([p(6, 7), p(11, 12), p(6, 17)])
                line.addLines([p(12, 7), p(17, 12), p(12, 17)])
                style.lineWidth = 2.4
            }
            context.stroke(line, with: .color(ArrowDrawing.colour(for: kind).color), style: style)
        }
        .accessibilityHidden(true)
    }
}
