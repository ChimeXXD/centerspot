import Foundation
import Testing
@testable import Agmen

/// Zone words and VoiceOver labels in football language (SPEC §8, D2-5).
struct PlacementTests {
    @Test(arguments: [
        (0.5, 0.97, "six-yard box"), (0.5, 0.90, "penalty area"), (0.5, 0.82, "edge of the box"),
        (0.5, 0.50, "centre circle"), (0.05, 0.50, "left wing, middle third"), (0.30, 0.75, "left half-space, final third"),
        (0.50, 0.25, "centre, defensive third"), (0.90, 0.60, "right wing, middle third"), (0.70, 0.40, "right half-space, middle third"),
        (0.50, 0.03, "own six-yard box"), (0.50, 0.12, "own penalty area"), (0.50, 0.18, "edge of own box"),
    ])
    func zoneWords(x: Double, y: Double, expected: String) {
        #expect(Placement.zone(of: Point(x: x, y: y), on: .full) == expected)
    }

    @Test func boxesScaleWithSmallerPitches() {
        // A 5-a-side box is drawn to the same proportions, so the same normalised point reads the same.
        #expect(Placement.zone(of: Point(x: 0.5, y: 0.90), on: .fiveASide) == "penalty area")
        #expect(Placement.zone(of: Point(x: 0.5, y: 0.5), on: .sevenASide) == "centre circle")
    }

    @Test func heroStrikerLabelReadsLikeACoach() throws {
        let hero = try Fixtures.tactic("overlap-left"), presets = try Presets.bundled()
        let nine = try #require(hero.tokens.first { $0.id == "h9" })
        let label = Placement.label(for: nine, in: hero, stepIndex: 3, roles: presets.roles)
        #expect(label == "Number 9, striker, edge of the box, step 4 of 5")
    }

    @Test func awayPlayersBallAndUnnumberedTokensAreNamed() throws {
        let hero = try Fixtures.tactic("overlap-left"), roles = try Presets.bundled().roles
        let theirKeeper = try #require(hero.tokens.first { $0.id == "a1" })
        #expect(Placement.label(for: theirKeeper, in: hero, stepIndex: 0, roles: roles) == "Their number 1, goalkeeper, six-yard box, step 1 of 5")
        let ball = try #require(hero.tokens.first { $0.kind == .ball })
        #expect(Placement.label(for: ball, in: hero, stepIndex: 0, roles: roles).hasPrefix("Ball, "))
        let named = Token(id: "x", kind: .player, side: .home, name: "Ade")
        var t = hero; t.tokens.append(named); t.phases[0].steps[0].positions["x"] = Point(x: 0.5, y: 0.5)
        #expect(Placement.label(for: named, in: t, stepIndex: 0, roles: roles) == "Ade, centre circle, step 1 of 5")
        // A named away player without a number still says which side they're on (D-15).
        let theirs = Token(id: "y", kind: .player, side: .away, name: "Ade")
        t.tokens.append(theirs); t.phases[0].steps[0].positions["y"] = Point(x: 0.5, y: 0.5)
        #expect(Placement.label(for: theirs, in: t, stepIndex: 0, roles: roles) == "Ade, their player, centre circle, step 1 of 5")
    }

    @Test func withoutAStepTheLabelLeavesTheStepOut() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let nine = try #require(hero.tokens.first { $0.id == "h9" })
        #expect(Placement.label(for: nine, in: hero, stepIndex: 3, roles: try Presets.bundled().roles, includeStep: false)
                == "Number 9, striker, edge of the box")
    }
}
