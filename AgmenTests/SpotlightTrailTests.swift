import CoreGraphics
import Foundation
import Testing
@testable import Agmen

/// D-40: the spotlit player's trail is where `Timeline` had them over the last 0.8 s, and the spotlight only ever
/// changes exports: the renderer rings the player and dims the rest when asked, and draws as before when not.
struct SpotlightTrailTests {
    @Test func theTrailIsTheTimelinesPathEndingWhereThePlayerIs() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let t = 2.4
        let trail = SpotlightTrail.points(of: "h3", at: t, in: hero)
        #expect(trail.count >= 2 && trail.count <= SpotlightTrail.samples, "\(trail.count) points")
        #expect(trail.last == Timeline.state(at: t, in: hero).positions["h3"])
        #expect(trail.first == Timeline.state(at: t - SpotlightTrail.length, in: hero).positions["h3"])
        let sampled = (0..<SpotlightTrail.samples).compactMap { i in
            Timeline.state(at: t - SpotlightTrail.length * Double(SpotlightTrail.samples - 1 - i) / Double(SpotlightTrail.samples - 1),
                           in: hero).positions["h3"]
        }
        #expect(trail.allSatisfy { sampled.contains($0) }, "every point is on the timeline")
    }

    @Test func standingStillLeavesNoTrailAndItNeverReachesBeforeTheStart() throws {
        let hero = try Fixtures.tactic("overlap-left")
        #expect(SpotlightTrail.points(of: "h3", at: 0.2, in: hero).count == 1, "still during the first hold")
        let early = SpotlightTrail.points(of: "h3", at: 0.5, in: hero)
        #expect(early.first == Timeline.state(at: 0, in: hero).positions["h3"])
        #expect(SpotlightTrail.points(of: "nobody", at: 2, in: hero).isEmpty)
        #expect(SpotlightTrail.points(of: "h3", at: 2.4, in: hero) == SpotlightTrail.points(of: "h3", at: 2.4, in: hero))
    }

    /// Rendered: the spotlit player keeps full colour and gets a ring; another player is dimmed; the ball is not.
    @Test func theRendererRingsThePlayerAndDimsTheRest() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let size = CGSize(width: 340, height: 525)
        let state = Timeline.state(at: 2.4, in: hero)
        let spot = BoardRenderer.Spotlight(tokenID: "h3", trail: SpotlightTrail.points(of: "h3", at: 2.4, in: hero))
        let plain = try #require(BoardRenderer.image(state: state, tactic: hero, size: size))
        let lit = try #require(BoardRenderer.image(state: state, tactic: hero, size: size, options: .init(spotlight: spot)))
        let g = BoardGeometry(kind: hero.pitch.kind, fitting: CGRect(origin: .zero, size: size))
        let centres = g.drawnCentres(positions: state.positions, tokens: hero.tokens, carry: state.carry)
        let three = try #require(centres["h3"]), nine = try #require(centres["h9"]), ball = try #require(centres["ball"])
        #expect(try pixel(plain, three) == pixel(lit, three), "the spotlit player keeps their colour")
        #expect(try pixel(plain, nine) != pixel(lit, nine), "the others dim")
        #expect(try pixel(plain, ball) == pixel(lit, ball), "the ball does not")
        let ring = CGPoint(x: three.x + g.tokenRadius * 1.5, y: three.y)
        #expect(try pixel(lit, ring).g > 200 && pixel(plain, ring).g < 200, "a white ring around them")
    }

    /// The fading trail is really drawn: on its newest stretch, clear of the player's disc and ring, the spotlit
    /// frame is lighter than the plain one.
    @Test func theTrailIsDrawnBehindThePlayer() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let size = CGSize(width: 340, height: 525)
        let state = Timeline.state(at: 2.4, in: hero)
        let trail = SpotlightTrail.points(of: "h3", at: 2.4, in: hero)
        let spot = BoardRenderer.Spotlight(tokenID: "h3", trail: trail)
        let plain = try #require(BoardRenderer.image(state: state, tactic: hero, size: size))
        let lit = try #require(BoardRenderer.image(state: state, tactic: hero, size: size, options: .init(spotlight: spot)))
        let g = BoardGeometry(kind: hero.pitch.kind, fitting: CGRect(origin: .zero, size: size))
        let three = try #require(g.drawnCentres(positions: state.positions, tokens: hero.tokens, carry: state.carry)["h3"])
        // The newest trail point at least two ring-widths from the player: inside the trail, outside disc and ring.
        let clear = trail.reversed().map(g.point).first { hypot($0.x - three.x, $0.y - three.y) > g.tokenRadius * 2.2 }
        let spotOnTrail = try #require(clear, "the trail reaches beyond the ring at t = 2.4")
        let a = try pixel(plain, spotOnTrail), b = try pixel(lit, spotOnTrail)
        #expect(b.r + b.g + b.b > a.r + a.g + a.b + 60, "plain \(a), spotlit \(b)")
    }

    /// Without a spotlight, nothing changes (the board on screen never gets one).
    @Test func noSpotlightIsTheSameBoard() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let state = Timeline.state(at: 2.4, in: hero)
        let size = CGSize(width: 340, height: 525)
        let a = try VideoReader.bgra(try #require(BoardRenderer.image(state: state, tactic: hero, size: size)))
        let b = try VideoReader.bgra(try #require(BoardRenderer.image(state: state, tactic: hero, size: size,
                                                                        options: .init(spotlight: nil))))
        #expect(a == b)
    }

    private func pixel(_ image: CGImage, _ p: CGPoint) throws -> (r: Int, g: Int, b: Int) {
        let crop = try #require(image.cropping(to: CGRect(x: Int(p.x), y: Int(p.y), width: 1, height: 1)))
        let bytes = try VideoReader.bgra(crop)
        try #require(bytes.count == 4)
        return (Int(bytes[2]), Int(bytes[1]), Int(bytes[0]))
    }
}
