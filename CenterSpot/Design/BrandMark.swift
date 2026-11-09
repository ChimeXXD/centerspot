import SwiftUI

/// The CenterSpot mark (D-86, design system › Logo): the halfway line, the centre circle tilted the way the Broadcast
/// camera sees it (near side thicker), and the lime centre spot. Drawn from its 100-unit grid at any size.
struct BrandMark: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 100
            let origin = CGPoint(x: (size.width - 100 * s) / 2, y: (size.height - 100 * s) / 2)
            func rect(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGRect {
                CGRect(x: origin.x + (cx - rx) * s, y: origin.y + (cy - ry) * s, width: 2 * rx * s, height: 2 * ry * s)
            }
            let ink = Tokens.Colour.text.color
            var line = SwiftUI.Path()
            line.move(to: CGPoint(x: origin.x + 8 * s, y: origin.y + 55 * s))
            line.addLine(to: CGPoint(x: origin.x + 92 * s, y: origin.y + 55 * s))
            context.stroke(line, with: .color(ink), style: StrokeStyle(lineWidth: 6 * s, lineCap: .round))
            // The ring: the outer ellipse less an inner one raised 2.5 units, so the far side is thin and the near side
            // thick. The halfway line shows through its hole.
            var ring = SwiftUI.Path(ellipseIn: rect(50, 56, 33, 17))
            ring.addPath(SwiftUI.Path(ellipseIn: rect(50, 53.5, 26, 10.5)))
            context.fill(ring, with: .color(ink), style: FillStyle(eoFill: true))
            context.fill(SwiftUI.Path(ellipseIn: rect(50, 55, 9, 5.5)), with: .color(Tokens.Colour.accent.color))
        }
        .accessibilityHidden(true)
    }
}

/// The mark beside the wordmark: the library's title.
struct BrandLockup: View {
    var markSize: CGFloat = 28

    var body: some View {
        HStack(spacing: Tokens.Space.s2) {
            BrandMark().frame(width: markSize, height: markSize)
            Text("CenterSpot")
                .font(Tokens.Typeface.wordmarkSmall)
                .foregroundStyle(Tokens.Colour.text.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("library.title")
    }
}
