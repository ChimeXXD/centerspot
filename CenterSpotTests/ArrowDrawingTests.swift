import CoreGraphics
import Foundation
import Testing
@testable import CenterSpot

/// D-72 in the renderer: a dribble keeps its wave along whatever shape is stored (2 points straight, 25 curved), and
/// an arrow that ends on a player stops short of the disc however finely its path is sampled.
struct ArrowDrawingTests {
    private static func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }

    /// Open grass on the left of `TestTactics.small()`'s step 2, clear of every token.
    static let straight = [p(0.1, 0.3), p(0.1, 0.62)]
    static let curved = ShapedPath.path(for: [p(0.1, 0.3), p(0.25, 0.46), p(0.1, 0.62)], shape: .curved)

    /// How far either side of the stored line the dribble's colour reaches, at `samples` places along it (screen points,
    /// positive to the left of the direction of travel).
    private static func reach(of points: [Point], samples: Int = 40) throws -> [(left: CGFloat, right: CGFloat)] {
        var tactic = TestTactics.small()
        tactic.phases[0].steps[1].arrows = [Arrow(kind: .dribble, points: points)]
        let frame = try BoardRendererTests.render(tactic, step: 1)
        let line = points.map(frame.geometry.point)
        let k = frame.geometry.scale
        var result: [(left: CGFloat, right: CGFloat)] = []
        for i in 0..<samples {
            // From a tenth of the way to three quarters: clear of the start cap and of the head.
            let (at, normal) = Self.walk(line, to: 0.1 + 0.65 * CGFloat(i) / CGFloat(samples - 1))
            var left: CGFloat = 0, right: CGFloat = 0
            for step in -32...32 {
                let off = CGFloat(step) * 0.25 * k
                let c = frame.colour(at: CGPoint(x: at.x + normal.dx * off, y: at.y + normal.dy * off))
                guard BoardRendererTests.close(c, Tokens.Colour.dribble, within: 40) else { continue }
                left = max(left, off)
                right = max(right, -off)
            }
            result.append((left, right))
        }
        return result
    }

    /// The point `fraction` of the way along a polyline and the unit normal of the segment it falls on.
    private static func walk(_ line: [CGPoint], to fraction: CGFloat) -> (CGPoint, CGVector) {
        let lengths = zip(line, line.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
        var remaining = fraction * lengths.reduce(0, +)
        for (i, length) in lengths.enumerated() where length > 0 {
            if remaining <= length || i == lengths.count - 1 {
                let a = line[i], b = line[i + 1], s = remaining / length
                return (CGPoint(x: a.x + (b.x - a.x) * s, y: a.y + (b.y - a.y) * s),
                        CGVector(dx: -(b.y - a.y) / length, dy: (b.x - a.x) / length))
            }
            remaining -= length
        }
        return (line[0], CGVector(dx: 0, dy: 0))
    }

    @Test(arguments: ["straight", "curved"])
    func aDribbleWavesToBothSidesOfItsLine(name: String) throws {
        let reach = try Self.reach(of: name == "curved" ? Self.curved : Self.straight)
        #expect(Self.curved.count == ShapedPath.curveSamples)
        let k = try BoardRendererTests.render(TestTactics.small()).geometry.scale
        // The wave swings 3.5 pt either side with a 2.6 pt line: well past 2.5 pt on each side, not just past the line.
        let left = reach.filter { $0.left > 2.5 * k }.count
        let right = reach.filter { $0.right > 2.5 * k }.count
        #expect(left >= reach.count / 4 && right >= reach.count / 4, "\(name): left \(left), right \(right) of \(reach.count)")
        #expect(reach.allSatisfy { max($0.left, $0.right) < 6 * k }, "\(name): the wave stays on its line")
    }

    /// The renderer pulls an arrow's end back off a disc by arc length, not just along its last (tiny) segment.
    @Test func theEndIsPulledBackAlongTheWholeLine() {
        let line = (0...24).map { CGPoint(x: 100, y: 300 - CGFloat($0) * 5) }   // 120 pt up, 5 pt segments
        let trimmed = ArrowDrawing.trimmedEnd(line, by: 17)
        #expect(abs((trimmed.last?.y ?? 0) - 197) < 1e-9, "17 pt back from the end")
        #expect(trimmed.count == 22 && trimmed.dropLast().allSatisfy { $0.y > 197 })
        let short = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 10)]
        #expect(ArrowDrawing.trimmedEnd(short, by: 17).last == CGPoint(x: 0, y: 5), "never more than half of it")
        #expect(ArrowDrawing.trimmedEnd(short, by: 3).last == CGPoint(x: 0, y: 7))
    }
}
