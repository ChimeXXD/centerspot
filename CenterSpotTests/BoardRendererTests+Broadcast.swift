import CoreGraphics
import Foundation
import Testing
@testable import CenterSpot

/// The broadcast restyle in `BoardRenderer` (D-65, D-67): marks lie on the grass under the discs in the mockup's order,
/// every disc has a thin dark outline, and every number is drawn after every disc.
extension BoardRendererTests {
    typealias T = TestTactics

    /// Pixels in `rect` (board points) that are near-black: number ink (#0B0F14) or a dark outline.
    static func darkPixels(in frame: Frame, _ rect: CGRect) -> Int {
        var count = 0
        for y in stride(from: rect.minY, to: rect.maxY, by: 1 / scale) {
            for x in stride(from: rect.minX, to: rect.maxX, by: 1 / scale) {
                let c = frame.colour(at: CGPoint(x: x, y: y))
                if c.r < 70 && c.g < 70 && c.b < 70 { count += 1 }
            }
        }
        return count
    }

    /// D-67 rule 1 (the 9/5 overlap in the example): a disc drawn after a neighbour never covers their number.
    @Test func everyNumberIsDrawnAfterEveryDisc() throws {
        let hero = try Fixtures.tactic("overlap-left")
        var state = Timeline.restingState(step: 0, in: hero)
        let geometry = BoardGeometry(kind: .full, fitting: CGRect(origin: .zero, size: Self.size))
        let nine = try #require(state.positions["h9"])
        // 7 is drawn after 9 (board order); put their disc over the right of 9's number, clear of 7's own number.
        state.positions["h7"] = Point(x: nine.x + 0.9 * BoardGeometry.tokenRadiusRatio, y: nine.y)
        let frame = try Self.render(hero, state: state)
        let c = geometry.point(nine), r = geometry.tokenRadius
        let band = CGRect(x: c.x + 0.02 * r, y: c.y - 0.34 * r, width: 0.3 * r, height: 0.64 * r)
        #expect(Self.darkPixels(in: frame, band) > 20, "9's number shows over 7's disc")
        // The same band with no number there is all lime (the check isn't seeing something else).
        var unnumbered = hero
        if let i = unnumbered.tokens.firstIndex(where: { $0.id == "h9" }) { unnumbered.tokens[i].number = nil }
        #expect(Self.darkPixels(in: try Self.render(unnumbered, state: state), band) == 0)
    }

    /// D-67 rule 2: a thin dark outline holds every disc on heat (home disc and away ring alike).
    @Test(arguments: ["h6", "a5"])
    func everyDiscHasAThinDarkOutline(player: String) throws {
        let hero = try Fixtures.tactic("overlap-left")
        let at = try #require(Timeline.restingState(step: 0, in: hero).positions[player])
        let heated = T.changing(hero, step: 0) { $0.marks = Marks(glows: [Glow(id: "g", target: .spot(at, radius: 0.12))]) }
        let frame = try Self.render(heated)
        let c = try frame.centre(player), r = frame.r
        let edge = player.hasPrefix("a") ? 1.02 * r : r
        let outline = frame.colour(at: CGPoint(x: c.x + edge + TokenDrawing.outlineWidth * r / 2, y: c.y))
        #expect(Self.close(outline, Tokens.Colour.discOutline, within: 30), "outline: \(outline)")
        let beyond = frame.colour(at: CGPoint(x: c.x + edge + TokenDrawing.outlineWidth * r * 2, y: c.y))
        #expect(beyond.r > 120, "heat just beyond it: \(beyond)")
    }

    @Test func theMarksLieOnTheGrassUnderTheDiscs() throws {
        // Without step 4's pass, whose head ends beside the heat.
        let hero = T.changing(try Fixtures.tactic("overlap-left"), step: 3) { $0.arrows = [] }
        let frame = try Self.render(hero, step: 3)
        let bare = try Self.render(T.changing(hero, step: 3) { $0.marks = Marks() }, step: 3)
        let g = frame.geometry

        // The zone's see-through fill on the grass (a stripe-B band, clear of players).
        let inZone = frame.colour(at: g.point(Point(x: 0.05, y: 0.65)))
        #expect(Self.close(inZone, Tokens.Colour.zoneFill.over(Tokens.Colour.bcPitchB)), "zone: \(inZone)")
        // Heat's hot centre.
        let heat = frame.colour(at: g.point(Point(x: 0.5, y: 0.87)))
        #expect(Self.close(heat, Tokens.Colour.heatCore.opacity(0.7).over(Tokens.Colour.bcPitchB), within: 6), "heat: \(heat)")
        // Their back line between 2 and 5, in their kit (9 stands between 5 and 4).
        let two = try frame.centre("a2"), five = try frame.centre("a5")
        let between = CGPoint(x: (two.x + five.x) / 2, y: (two.y + five.y) / 2)
        let line = frame.colour(at: between), lineBare = bare.colour(at: between)
        #expect(Self.close(line, Tokens.kit(.coral).fill.opacity(Double(MarkDrawing.lineOpacity)).over(Tokens.Colour.bcPitchB), within: 30),
                "line: \(line)")
        #expect(abs(line.g - lineBare.g) > 40 || abs(line.r - lineBare.r) > 40, "line \(line) vs none \(lineBare)")
        // 3's rings, in our kit, round their disc.
        let three = try frame.centre("h3")
        let ring = frame.colour(at: CGPoint(x: three.x + 1.85 * frame.r, y: three.y))
        let ringBare = bare.colour(at: CGPoint(x: three.x + 1.85 * frame.r, y: three.y))
        #expect(ring.g - ringBare.g > 60, "ring \(ring) vs none \(ringBare)")
        // Under the discs: 3's fill is untouched by the zone and rings under them, and their 2's dark centre, inside the
        // zone, shows only its 15% see-through share of the zone's tint (over the disc it would add ~30 to green).
        #expect(Self.close(frame.colour(at: CGPoint(x: three.x, y: three.y - 0.75 * frame.r)), Tokens.kit(.lime).fill))
        let centreOfTwo = CGPoint(x: two.x - 0.55 * frame.r, y: two.y - 0.5 * frame.r)
        let inside = frame.colour(at: centreOfTwo), insideBare = bare.colour(at: centreOfTwo)
        #expect(abs(inside.g - insideBare.g) <= 8, "2's centre \(inside) vs no marks \(insideBare)")
    }

    @Test func aSelectedZoneShowsItsHandlesAndAPendingLineItsRing() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let frame = try Self.render(hero, step: 3, options: .init(selectedMark: "z1", pendingLine: ["h8", "h10"]))
        let zone = try #require(try T.marks(3, of: hero).zones.first)
        let box = MarkDrawing.rect(of: zone, g: frame.geometry)
        // The top right handle (the top left one sits partly off the pitch).
        let handle = frame.colour(at: CGPoint(x: box.maxX, y: box.minY))
        #expect(Self.close(handle, Tokens.Colour.text, within: 8), "handle: \(handle)")
        let unselected = try Self.render(hero, step: 3)
        #expect(!Self.close(unselected.colour(at: CGPoint(x: box.maxX, y: box.minY)), Tokens.Colour.text, within: 60))
        // The pending line from 8 to 10 in our kit, and a dashed ring round 10, the last tapped.
        let eight = try frame.centre("h8"), ten = try frame.centre("h10")
        let mid = CGPoint(x: (eight.x + ten.x) / 2, y: (eight.y + ten.y) / 2)
        #expect(Self.close(frame.colour(at: mid), Tokens.kit(.lime).fill.opacity(0.9).over(Tokens.Colour.bcPitchA), within: 30)
                || Self.close(frame.colour(at: mid), Tokens.kit(.lime).fill.opacity(0.9).over(Tokens.Colour.bcPitchB), within: 30),
                "pending line: \(frame.colour(at: mid))")
        var limeOnRing = 0
        for i in 0..<72 {
            let a = Double(i) * .pi / 36, rr = MarkDrawing.pendingRingRadius * frame.r
            let p = CGPoint(x: ten.x + rr * CGFloat(cos(a)), y: ten.y + rr * CGFloat(sin(a)))
            if frame.colour(at: p).g > 150 { limeOnRing += 1 }
        }
        #expect(limeOnRing > 15 && limeOnRing < 65, "dashed, not solid: \(limeOnRing) of 72")
    }

    @Test func linesAndRingsFollowTheirPlayersMidMove() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let marks = Marks(lines: [ShapeLine(id: "l", tokens: ["h5", "h4"])], glows: [Glow(id: "g", target: .token("h9"))])
        var tactic = T.changing(hero, step: 0) { $0.marks = marks }
        tactic = T.changing(tactic, step: 1) { $0.marks = marks }
        let state = Timeline.state(at: 0.9, in: tactic)  // mid move from step 1 to 2
        let frame = try Self.render(tactic, state: state)
        let nine = try frame.centre("h9")
        let ring = frame.colour(at: CGPoint(x: nine.x, y: nine.y - 1.85 * frame.r))
        #expect(ring.g > 100, "the ring is round 9 where 9 is now: \(ring)")
        let five = try frame.centre("h5"), four = try frame.centre("h4")
        let mid = frame.colour(at: CGPoint(x: (five.x + four.x) / 2, y: (five.y + four.y) / 2))
        #expect(mid.g > 150, "the line joins 5 and 4 where they are now: \(mid)")
    }
}
