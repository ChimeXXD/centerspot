import Foundation
import Testing
@testable import CenterSpot

/// D-94: scenarios are built by rules, and `mockup/scenarios.js` is the spec. `Fixtures/scenarios.json` holds what the
/// mockup builds for nine shapes across the three sizes, every scenario, attacking and defending; the app must build
/// the same players, numbers and positions.
struct ScenarioTests {
    struct File: Decodable {
        struct Player: Decodable { let number: Int; let role: String; let x: Double; let y: Double }
        struct Case: Decodable {
            let id: String
            let formation: String
            let attacking: Bool
            let home: [Player]
            let away: [Player]
            let ball: Point
        }
        let catalogue: [String: [String]]
        let cases: [Case]
    }

    private static func file() throws -> File {
        let url = try #require(Bundle(for: ScenarioBundleToken.self).url(forResource: "scenarios", withExtension: "json"))
        return try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
    }

    @Test func eachSizeOffersTheMockupsScenariosInItsOrder() throws {
        let catalogue = try Self.file().catalogue
        for kind in Pitch.Kind.allCases {
            #expect(Scenario.available(for: kind).map(\.id) == catalogue[kind.rawValue], "\(kind)")
        }
    }

    @Test func everyCaseIsBuiltAsTheMockupBuildsIt() throws {
        let cases = try Self.file().cases
        #expect(cases.count == 364)
        for c in cases {
            let scenario = try #require(Scenario.all.first { $0.id == c.id }, "\(c.id)")
            let formation = try #require(Presets.shared.formation(c.formation), "\(c.formation)")
            let board = try #require(scenario.build(with: formation, attacking: c.attacking), "\(c.id) \(c.formation)")
            let label = "\(c.id) · \(c.formation) · \(c.attacking ? "attacking" : "defending")"
            Self.expectSame(board.home, c.home, "\(label) · home")
            Self.expectSame(board.away, c.away, "\(label) · away")
            #expect(abs(board.ball.x - c.ball.x) < 0.0015 && abs(board.ball.y - c.ball.y) < 0.0015, "\(label) · ball \(board.ball)")
        }
    }

    private static func expectSame(_ got: [ScenarioBoard.Player], _ want: [File.Player], _ label: String) {
        #expect(got.map(\.number) == want.map(\.number), "\(label): numbers \(got.map(\.number)) vs \(want.map(\.number))")
        #expect(got.map(\.roleID) == want.map(\.role), "\(label): roles")
        for (g, w) in zip(got, want) where abs(g.point.x - w.x) >= 0.0015 || abs(g.point.y - w.y) >= 0.0015 {
            Issue.record("\(label): \(g.number) at \(g.point), mockup \(w.x), \(w.y)")
        }
    }
}

private final class ScenarioBundleToken {}

/// D-94: "Use <scenario>" sets up the current step with both sides and the ball, keeping names by shirt number.
struct ScenarioApplyTests {
    private static let shape = Presets.shared.formation("4-3-3")!
    private static func scenario(_ id: String) -> Scenario { Scenario.all.first { $0.id == id }! }

    @Test func onABlankBoardItPlacesBothSidesAndTheBall() throws {
        let board = try #require(Self.scenario("3v2-counter").build(with: Self.shape, attacking: true))
        let tactic = Self.scenario("3v2-counter").apply(to: TacticDocument.blank(), formation: Self.shape, attacking: true, stepIndex: 0)
        let step = tactic.phases[0].steps[0]
        let home = tactic.tokens.filter { $0.kind == .player && $0.side == .home }
        let away = tactic.tokens.filter { $0.kind == .player && $0.side == .away }
        #expect(home.compactMap(\.number).sorted() == [7, 10, 11])
        #expect(away.compactMap(\.number).sorted() == [1, 4, 5])
        for (player, side) in board.home.map({ ($0, Side.ID.home) }) + board.away.map({ ($0, Side.ID.away) }) {
            let token = try #require(tactic.tokens.first { $0.side == side && $0.number == player.number })
            #expect(step.positions[token.id] == player.point, "\(side) \(player.number)")
            #expect(token.roleID == player.roleID)
        }
        let ball = try #require(tactic.tokens.first { $0.kind == .ball })
        #expect(step.positions[ball.id] == board.ball)
    }

    @Test func onTheExampleNamesStayAndOthersLeaveFromEveryStep() throws {
        var hero = try Fixtures.tactic("overlap-left")
        let nine = try #require(hero.tokens.firstIndex { $0.side == .home && $0.number == 9 })
        hero.tokens[nine].name = "Osimhen"
        let applied = Self.scenario("1v1-keeper").apply(to: hero, formation: Self.shape, attacking: true, stepIndex: 2)
        let home = applied.tokens.filter { $0.kind == .player && $0.side == .home }
        #expect(home.count == 1)
        #expect(home.first?.name == "Osimhen", "9 is the striker through on goal and keeps their name")
        #expect(applied.tokens.filter { $0.kind == .player && $0.side == .away }.map(\.number) == [1])
        #expect(applied.phases[0].steps.count == hero.phases[0].steps.count, "steps stay")
        let ids = Set(applied.tokens.map(\.id))
        for step in applied.phases[0].steps {
            #expect(Set(step.positions.keys).isSubset(of: ids), "no one left behind in a step")
        }
        #expect(applied.tokens.filter { $0.kind == .ball }.count == 1, "the ball is kept, not doubled")
        // The step it sets up starts clean: lines drawn there began where the old players stood.
        #expect(!hero.phases[0].steps[2].arrows.isEmpty || !hero.phases[0].steps[2].runs.isEmpty, "the example draws on step 3")
        #expect(applied.phases[0].steps[2].arrows.isEmpty && applied.phases[0].steps[2].runs.isEmpty)
    }

    @Test func aSmallerSizeTurnsThePitch() throws {
        let seven = try #require(Presets.shared.formation("7-2-3-1"))
        let applied = Self.scenario("counter").apply(to: TacticDocument.blank(), formation: seven, attacking: false, stepIndex: 0)
        #expect(applied.pitch.kind == .sevenASide)
        #expect(applied.tokens.filter { $0.kind == .player && $0.side == .home }.count == 7)
        #expect(applied.tokens.filter { $0.kind == .player && $0.side == .away }.count == 7)
    }

    @Test func everyScenarioFitsTheFileFormat() throws {
        for shape in Presets.shared.formations {
            for scenario in Scenario.available(for: shape.pitch) {
                for attacking in [true, false] {
                    let tactic = scenario.apply(to: TacticDocument.blank(), formation: shape, attacking: attacking, stepIndex: 0)
                    let data = try TacticFormat.encode(tactic)
                    #expect(throws: Never.self, "\(scenario.id) \(shape.id)") { try TacticFormat.decode(data) }
                }
            }
        }
    }
}
