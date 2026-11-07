import SwiftUI

/// A draw tool's icon as the mockup's tiles draw it (a 24 × 24 view box): an arrow kind's line style in its colour,
/// stretched to the frame, or a mark's picture (a see-through box, three joined dots, a glow) at its own shape.
struct ToolIcon: View {
    let tool: DrawTool

    var body: some View {
        Canvas { context, size in
            if let kind = tool.arrowKind {
                arrow(kind, in: &context, size: size)
            } else {
                // Marks keep their proportions (circles stay round), centred like the mockup's SVG.
                let s = min(size.width, size.height) / 24
                context.translateBy(x: (size.width - 24 * s) / 2, y: (size.height - 24 * s) / 2)
                context.scaleBy(x: s, y: s)
                mark(in: &context)
            }
        }
        .accessibilityHidden(true)
    }

    private func arrow(_ kind: Arrow.Kind, in context: inout GraphicsContext, size: CGSize) {
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

    private func mark(in context: inout GraphicsContext) {
        let home = Tokens.kit(.lime).fill.color
        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> SwiftUI.Path {
            SwiftUI.Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
        }
        switch tool {
        case .zone:
            let box = SwiftUI.Path(roundedRect: CGRect(x: 3, y: 5, width: 18, height: 14), cornerRadius: 1)
            context.fill(box, with: .color(Tokens.Colour.zoneFill.color))
            context.stroke(box, with: .color(Tokens.Colour.zoneStroke.color), lineWidth: 1.8)
        case .line:
            var line = SwiftUI.Path()
            line.addLines([CGPoint(x: 3, y: 15), CGPoint(x: 12, y: 9), CGPoint(x: 21, y: 13)])
            context.stroke(line, with: .color(home), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            for (x, y) in [(3.0, 15.0), (12.0, 9.0), (21.0, 13.0)] { context.fill(circle(x, y, 2.2), with: .color(home)) }
        case .glow:
            context.fill(circle(12, 12, 3.2), with: .color(Tokens.Colour.heat.color))
            context.stroke(circle(12, 12, 6.5), with: .color(home.opacity(0.8)), lineWidth: 1.6)
            context.stroke(circle(12, 12, 10), with: .color(home.opacity(0.4)), lineWidth: 1.4)
        case .run, .pass, .dribble, .press:
            break
        }
    }
}
