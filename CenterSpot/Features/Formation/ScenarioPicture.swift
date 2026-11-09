import SwiftUI

/// A scenario tile's picture (D-94, mockup `pitchSVG`): the pitch turned with our attack to the right, both sides and
/// the ball where the scenario puts them. Team shapes show the whole pitch; small-sided games and set pieces are framed
/// on the play (the players and ball with a margin, at least half the pitch long, kept on the pitch). Discs keep one
/// size on screen however the picture is framed, which takes in the scenario's whole `move` (D-96), so a tile doesn't
/// jump when it starts playing. With `plays` (the picked tile) it loops the move: each step held, then eased to the
/// next, a pause on the last; with Reduce Motion it stays on the set-up.
struct ScenarioPicture: View {
    let board: ScenarioBoard
    let kind: Pitch.Kind
    var framesThePlay = false
    var move: [ScenarioMotion.Step]? = nil
    var plays = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the loop started: picking the tile (or changing its move) plays from the set-up, as the mockup's `load()`.
    @State private var started: Date?

    /// Where everyone stands at one moment: home, away, ball.
    private struct Scene {
        let home: [Point]
        let away: [Point]
        let ball: Point
    }

    /// The pause on the last step before the loop starts again.
    private static let endPause = 1.0

    var body: some View {
        Group {
            if plays, let move, move.count > 1, !reduceMotion {
                TimelineView(.animation) { timeline in
                    canvas(scene(of: move, at: started.map { timeline.date.timeIntervalSince($0) } ?? 0))
                }
                .onAppear { started = .now }
                .onChange(of: move) { started = .now }
            } else {
                canvas(Scene(home: board.home.map(\.point), away: board.away.map(\.point), ball: board.ball))
            }
        }
        .aspectRatio(CGFloat(kind.size.length / kind.size.width), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.item * 2 / 3))
        .accessibilityHidden(true)
    }

    /// The move at `time` on a loop: as `Timeline` plays a move, each step held, then eased to the next.
    private func scene(of move: [ScenarioMotion.Step], at time: TimeInterval) -> Scene {
        let lengths = move.dropLast().map { Timeline.hold + $0.duration }
        let total = lengths.reduce(0, +) + Timeline.hold + Self.endPause
        var t = time.truncatingRemainder(dividingBy: total), k = 0
        while k < lengths.count, t >= lengths[k] {
            t -= lengths[k]
            k += 1
        }
        guard k < lengths.count, t > Timeline.hold else {
            let step = move[k]
            return Scene(home: step.home.map(\.point), away: step.away.map(\.point), ball: step.ball)
        }
        let u = min(1, (t - Timeline.hold) / move[k].duration), e = u < 0.5 ? 2 * u * u : 1 - pow(-2 * u + 2, 2) / 2
        func mix(_ a: Point, _ b: Point) -> Point { Point(x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e) }
        let a = move[k], b = move[k + 1]
        return Scene(home: zip(a.home, b.home).map { mix($0.point, $1.point) },
                     away: zip(a.away, b.away).map { mix($0.point, $1.point) }, ball: mix(a.ball, b.ball))
    }

    private func canvas(_ scene: Scene) -> some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            // Board point → picture point, turned: up the pitch is to the right, our left touchline at the top.
            func at(_ p: Point) -> CGPoint { CGPoint(x: p.y * w, y: p.x * h) }
            let r = max(4, w / 30)
            let frame = framesThePlay ? playFrame(w: w, h: h, radius: r, at: at) : CGRect(x: 0, y: 0, width: w, height: h)
            let k = frame.width / w
            context.scaleBy(x: 1 / k, y: 1 / k)
            context.translateBy(x: -frame.minX, y: -frame.minY)
            drawPitch(in: &context, w: w, h: h, line: max(1, w / 240) * k)
            let disc = r * k
            for p in scene.away { drawAway(at(p), radius: disc, in: &context) }
            for p in scene.home { drawHome(at(p), radius: disc, in: &context) }
            let ball = at(scene.ball)
            let ballRect = CGRect(x: ball.x + disc * 0.8 - disc * 0.5, y: ball.y + disc * 0.8 - disc * 0.5, width: disc, height: disc)
            context.fill(SwiftUI.Path(ellipseIn: ballRect), with: .color(Tokens.Colour.ball.color))
            context.stroke(SwiftUI.Path(ellipseIn: ballRect), with: .color(Tokens.Colour.discOutline.color), lineWidth: disc * 0.14)
        }
    }

    /// The part of the picture to show: the play (the whole move's, when it loops), with room round it, at the
    /// picture's aspect.
    private func playFrame(w: CGFloat, h: CGFloat, radius r: CGFloat, at: (Point) -> CGPoint) -> CGRect {
        var all = (board.home + board.away).map(\.point) + [board.ball]
        for step in move ?? [] { all += (step.home + step.away).map(\.point) + [step.ball] }
        let points = all.map(at)
        let xs = points.map(\.x), ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return CGRect(x: 0, y: 0, width: w, height: h)
        }
        let cw = min(w, max(w * 0.5, (maxX - minX) * 1.4 + r * 6, ((maxY - minY) * 1.4 + r * 6) * w / h))
        let ch = cw * h / w
        let x = min(max((minX + maxX) / 2 - cw / 2, 0), w - cw)
        let y = min(max((minY + maxY) / 2 - ch / 2, 0), h - ch)
        return CGRect(x: x, y: y, width: cw, height: ch)
    }

    /// Stripes and the markings, in metres on the size's pitch, turned like the players.
    private func drawPitch(in context: inout GraphicsContext, w: CGFloat, h: CGFloat, line: CGFloat) {
        for i in 0..<8 {
            let stripe = CGRect(x: CGFloat(i) * w / 8, y: 0, width: w / 8, height: h)
            context.fill(SwiftUI.Path(stripe), with: .color((i % 2 == 0 ? Tokens.Colour.bcPitchA : Tokens.Colour.bcPitchB).color))
        }
        let length = kind.size.length, width = kind.size.width
        func m(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: y / length * w, y: x / width * h) }
        func box(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> SwiftUI.Path {
            let a = m(x0, y0), b = m(x1, y1)
            return SwiftUI.Path(CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y)))
        }
        let boxW = min(40.3, width * 0.6), boxD = min(16.5, length * 0.16)
        let sixW = min(18.3, width * 0.3), sixD = min(5.5, length * 0.06)
        var lines = box(0, 0, width, length)
        lines.move(to: CGPoint(x: w / 2, y: 0))
        lines.addLine(to: CGPoint(x: w / 2, y: h))
        let circle = min(9.15, width * 0.13) / width * h
        lines.addEllipse(in: CGRect(x: w / 2 - circle, y: h / 2 - circle, width: 2 * circle, height: 2 * circle))
        lines.addPath(box((width - boxW) / 2, 0, (width + boxW) / 2, boxD))
        lines.addPath(box((width - boxW) / 2, length - boxD, (width + boxW) / 2, length))
        lines.addPath(box((width - sixW) / 2, 0, (width + sixW) / 2, sixD))
        lines.addPath(box((width - sixW) / 2, length - sixD, (width + sixW) / 2, length))
        context.stroke(lines, with: .color(Tokens.Colour.bcLine.color), lineWidth: line)
    }

    private func circle(_ c: CGPoint, _ r: CGFloat) -> SwiftUI.Path {
        SwiftUI.Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    private func drawHome(_ c: CGPoint, radius r: CGFloat, in context: inout GraphicsContext) {
        context.fill(circle(c, r * 1.1), with: .color(Tokens.Colour.discOutline.color))
        context.fill(circle(c, r), with: .color(Tokens.kit(.lime).fill.color))
    }

    private func drawAway(_ c: CGPoint, radius r: CGFloat, in context: inout GraphicsContext) {
        context.fill(circle(c, r * 1.12), with: .color(Tokens.Colour.discOutline.color))
        context.fill(circle(c, r * 0.9), with: .color(Tokens.Colour.awayInner.color))
        context.stroke(circle(c, r * 0.9), with: .color(Tokens.kit(.coral).fill.color), lineWidth: r * 0.24)
    }
}
