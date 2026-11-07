import Foundation
import Testing
@testable import Agmen

/// D2-5: VoiceOver reads every player of a 4-3-3 in football words, and the adjustable action moves a player by
/// `Nudge.step`, staying on the pitch.
struct BoardAccessibilityTests {
    @Test func everyPlayerOfAFourThreeThreeHasANumberRoleAndZone() throws {
        let presets = try Presets.bundled()
        let shape = try #require(presets.formation("4-3-3"))
        let tactic = shape.apply(to: TacticDocument.blank(), stepIndex: 0)
        let players = tactic.tokens.filter { $0.kind == .player }
        #expect(players.count == 11)
        for token in players {
            let label = Placement.label(for: token, in: tactic, stepIndex: 0, roles: presets.roles)
            let number = try #require(token.number)
            let role = try #require(presets.role(try #require(token.roleID)))
            #expect(label.hasPrefix("Number \(number), \(role.name.lowercased()), "), "\(label)")
            #expect(label.hasSuffix(", step 1 of 1"), "\(label)")
            // number, role, zone, step: the zone is never empty
            #expect(label.split(separator: ",").count >= 4, "\(label)")
        }
    }

    @Test(arguments: [
        (Nudge.up, Point(x: 0.5, y: 0.52)), (.down, Point(x: 0.5, y: 0.48)),
        (.left, Point(x: 0.48, y: 0.5)), (.right, Point(x: 0.52, y: 0.5)),
    ])
    func aNudgeMovesTwoPercentOfThePitch(_ nudge: Nudge, _ expected: Point) {
        let moved = nudge.applied(to: Point(x: 0.5, y: 0.5))
        #expect(abs(moved.x - expected.x) < 1e-9 && abs(moved.y - expected.y) < 1e-9)
    }

    @Test func aNudgeStopsAtTheEdgeOfThePitch() {
        #expect(Nudge.up.applied(to: Point(x: 0.5, y: 0.99)) == Point(x: 0.5, y: 1))
        #expect(Nudge.left.applied(to: Point(x: 0.01, y: 0.5)) == Point(x: 0, y: 0.5))
    }

    @Test func anIncrementMovesThePlayerInTheTactic() throws {
        var hero = try Fixtures.tactic("overlap-left")
        let start = try #require(Timeline.restingState(step: 0, in: hero).positions["h9"])
        TacticEdits.moveToken("h9", to: Nudge.up.applied(to: start), step: 0, in: &hero)
        let moved = try #require(Timeline.restingState(step: 0, in: hero).positions["h9"])
        #expect(abs(moved.y - (start.y + Nudge.step)) < 1e-9)
        #expect(moved.x == start.x)
    }
}
