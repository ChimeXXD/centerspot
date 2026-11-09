import CoreGraphics
import Foundation
import Testing
@testable import CenterSpot

/// BR-2 (D-66, D-67): `BoardRenderer` through the broadcast camera. The pitch narrows away from the viewer, discs lie
/// flat on the grass where the camera puts them, nearer discs cover farther ones, numbers stay upright, and marks and
/// arrows are on the grass too.
extension BoardRendererTests {
    /// `small()` on a striped pitch, `h9` (blue) at the middle and the camera on it.
    static func cameraScene(numbers: Bool = true) -> (Tactic, BoardState, BroadcastCamera) {
        var tactic = TestTactics.small()
        tactic.pitch.style = .plain
        if !numbers { for i in tactic.tokens.indices { tactic.tokens[i].number = nil } }
        tactic.phases[0].steps[0].arrows = []
        var state = Timeline.restingState(step: 0, in: tactic)
        state.positions["h9"] = Point(x: 0.5, y: 0.6)
        let target = Point(x: 0.5, y: 0.6)
        return (tactic, state, BroadcastCamera(view: CGRect(origin: .zero, size: size), kind: .full, target: target))
    }

    static func broadcast(_ tactic: Tactic, _ state: BoardState, at target: Point = Point(x: 0.5, y: 0.6)) throws -> Frame {
        try render(tactic, state: state, options: .init(broadcast: target))
    }

    /// On the left wing the camera stops panning with the touchline in the bottom corner; farther up, the touchline
    /// leans in toward the middle, as a line going away does.
    @Test func theBroadcastPitchNarrowsAwayFromTheCamera() throws {
        let (tactic, state, _) = Self.cameraScene()
        let wing = Point(x: 0, y: 0.6)
        let camera = BroadcastCamera(view: CGRect(origin: .zero, size: Self.size), kind: .full, target: wing)
        let frame = try Self.broadcast(tactic, state, at: wing)
        // The grass (#0E1216) is 3 levels from the background (#0B0F14), so only an exact match counts as grass.
        func leftEdge(atY y: CGFloat) -> CGFloat? {
            stride(from: 0, to: Self.size.width, by: 0.5).first {
                Self.close(frame.colour(at: CGPoint(x: $0, y: y)), Tokens.Colour.bcPitchA, within: 1)
            }
        }
        let farLine = camera.project(camera.plane.point(Point(x: 0, y: 0.97)))
        let far = try #require(leftEdge(atY: farLine.y)), near = try #require(leftEdge(atY: Self.size.height - 4))
        #expect(abs(far - farLine.x) < 4, "far touchline at \(far), camera says \(farLine.x)")
        #expect(near < 4, "the near touchline is in the bottom corner: \(near)")
        #expect(far > near + 30, "far \(far), near \(near)")
    }

    @Test func aDiscLiesFlatWhereTheCameraPutsIt() throws {
        let (tactic, state, camera) = Self.cameraScene()
        let frame = try Self.broadcast(tactic, state)
        let p = camera.plane.point(Point(x: 0.5, y: 0.6)), c = camera.project(p)
        let r = camera.plane.tokenRadius * camera.depthScale(at: p)
        let fill = Tokens.kit(.blue).fill
        #expect(Self.close(frame.colour(at: CGPoint(x: c.x + 0.8 * r, y: c.y)), fill, within: 6), "right of the number")
        #expect(Self.close(frame.colour(at: CGPoint(x: c.x - 0.8 * r, y: c.y)), fill, within: 6), "left of the number")
        // Flat on the grass: as wide as ever, but shorter, so 0.85 r below the centre is past its edge.
        #expect(!Self.close(frame.colour(at: CGPoint(x: c.x, y: c.y + 0.85 * r)), fill, within: 30))
    }

    @Test func nearerDiscsAreDrawnOverFartherOnes() throws {
        var (tactic, state, camera) = Self.cameraScene(numbers: false)
        // a5 just beyond h9: in board order a5 is drawn after h9, but h9 is nearer the camera.
        state.positions["a5"] = Point(x: 0.5, y: 0.62)
        _ = tactic
        let frame = try Self.broadcast(tactic, state)
        let a = camera.project(camera.plane.point(Point(x: 0.5, y: 0.6)))
        let b = camera.project(camera.plane.point(Point(x: 0.5, y: 0.62)))
        let between = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        #expect(Self.close(frame.colour(at: between), Tokens.kit(.blue).fill, within: 6), "\(frame.colour(at: between))")
    }

    /// D-67: in the tilted camera the numbers stand up, the same shape as on the flat board. Measured on away 5, whose
    /// white number on a dark centre is the only bright thing on the disc (a home number's dark ink matches the pitch).
    @Test func numbersStayUpright() throws {
        var (tactic, state, camera) = Self.cameraScene()
        state.positions["h9"] = Point(x: 0.3, y: 0.3)
        state.positions["a5"] = Point(x: 0.5, y: 0.6)
        _ = tactic
        func numberBox(_ frame: Frame, around c: CGPoint, radius r: CGFloat) -> CGRect {
            var box = CGRect.null
            for y in stride(from: c.y - r, to: c.y + r, by: 1 / Self.scale) {
                for x in stride(from: c.x - r, to: c.x + r, by: 1 / Self.scale) {
                    let pixel = frame.colour(at: CGPoint(x: x, y: y))
                    if pixel.r > 200 && pixel.g > 200 && pixel.b > 200 { box = box.union(CGRect(x: x, y: y, width: 0, height: 0)) }
                }
            }
            return box
        }
        let flat = try Self.render(tactic, state: state)
        let flatBox = numberBox(flat, around: try flat.centre("a5"), radius: flat.r)
        let p = camera.plane.point(Point(x: 0.5, y: 0.6))
        let tilted = numberBox(try Self.broadcast(tactic, state), around: camera.project(p),
                               radius: camera.plane.tokenRadius * camera.depthScale(at: p))
        #expect(flatBox.height > 5 && tilted.height > 5, "flat \(flatBox), tilted \(tilted)")
        let flatShape = flatBox.height / flatBox.width, tiltedShape = tilted.height / tilted.width
        // A number painted on the grass would be about 22% shorter here; glyph edges measure to about 3%.
        #expect(abs(tiltedShape / flatShape - 1) < 0.1, "flat \(flatBox), tilted \(tilted)")
    }

    @Test func marksAndArrowsLieOnTheGrass() throws {
        let (plain, state, camera) = Self.cameraScene()
        let zone = Zone(id: "z", x: 0.1, y: 0.7, w: 0.3, h: 0.15, colour: .orange)
        let pass = Arrow(kind: .pass, points: [Point(x: 0.6, y: 0.4), Point(x: 0.9, y: 0.75)])
        var marked = plain
        marked.phases[0].steps[0].marks = Marks(zones: [zone])
        marked.phases[0].steps[0].arrows = [pass]
        var markedState = state
        markedState.marks = [.init(shape: .zone(zone), opacity: 1)]
        markedState.arrows = [.init(arrow: pass, opacity: 1)]
        let bare = try Self.broadcast(plain, state), drawn = try Self.broadcast(marked, markedState)
        let inZone = camera.project(camera.plane.point(Point(x: 0.25, y: 0.775)))
        #expect(bare.colour(at: inZone) != drawn.colour(at: inZone), "zone tint at \(inZone)")
        // The pass's first dash, 3 points along the line from its start.
        let start = camera.project(camera.plane.point(pass.points[0]))
        let end = camera.project(camera.plane.point(pass.points[1]))
        let len = hypot(end.x - start.x, end.y - start.y)
        let onLine = CGPoint(x: start.x + (end.x - start.x) / len * 3, y: start.y + (end.y - start.y) / len * 3)
        #expect(Self.close(drawn.colour(at: onLine), ArrowDrawing.colour(for: .pass), within: 40), "\(drawn.colour(at: onLine))")
    }

    @Test func theSameInstantDrawsTheSamePixels() throws {
        let (tactic, state, _) = Self.cameraScene()
        #expect(try Self.broadcast(tactic, state).pixels == Self.broadcast(tactic, state).pixels)
        #expect(try Self.broadcast(tactic, state).pixels != Self.render(tactic, state: state).pixels)
    }
}
