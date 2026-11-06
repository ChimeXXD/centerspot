import Foundation
import Testing
@testable import Agmen

/// SPEC §9 Core: every fixture decodes, re-encodes and decodes again to an equal `Tactic`;
/// an empty board round-trips; the written JSON uses FORMAT.md's key names.
struct FormatRoundTripTests {
    @Test(arguments: Fixtures.names)
    func fixtureRoundTrips(name: String) throws {
        let first = try TacticFormat.decode(Fixtures.data(name))
        let second = try TacticFormat.decode(TacticFormat.encode(first))
        #expect(first == second)
    }

    /// The fixtures are copies of `examples/` (D-29), so an edit to an example must reach the tests too.
    @Test(arguments: ["overlap-left", "five-a-side-long-ball"])
    func fixtureMatchesItsExample(name: String) throws {
        let repo = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let example = try Data(contentsOf: repo.appending(path: "examples/\(name).tactic"))
        #expect(try example == Fixtures.data(name), "AgmenTests/Fixtures/\(name).tactic differs from examples/")
    }

    @Test func emptyBoardRoundTrips() throws {
        let empty = try TacticFormat.decode(TacticDocument.emptyTactic())
        #expect(empty.tokens.isEmpty)
        #expect(empty.phases.map(\.steps.count) == [1])
        #expect(try TacticFormat.decode(TacticFormat.encode(empty)) == empty)
    }

    @Test func heroFixtureDecodesAsWritten() throws {
        let hero = try Fixtures.tactic("overlap-left")
        #expect(hero.title == "Overlap down the left")
        #expect(hero.pitch == Pitch(kind: .full, style: .stripes))
        #expect(hero.sides.map(\.id) == [.home, .away])
        #expect(hero.sides.map(\.colour) == [.lime, .coral])  // D-53
        #expect(hero.sides.map(\.rendering) == [.filled, .ring])
        #expect(hero.tokens.count == 17)
        let steps = try #require(hero.phases.first?.steps)
        #expect(steps.count == 5)
        #expect(steps[1].runs["h3"]?.points.count == 3)
        // Each step's arrows show the move about to happen (D-46).
        #expect(steps[1].arrows.map(\.kind) == [.dribble])
        #expect(steps[2].arrows.map(\.kind) == [.pass, .run])
        #expect(steps[0].positions["h3"] == Point(x: 0.15, y: 0.24))
        // Every token in the hero has a known role, so nothing was dropped.
        #expect(hero.tokens.filter { $0.kind == .player }.allSatisfy { $0.roleID != nil })
    }

    @Test func fullFixtureIsElevenAgainstElevenOverSixSteps() throws {
        let full = try Fixtures.tactic("full-11v11")
        #expect(full.tokens.filter { $0.side == .home }.count == 11)
        #expect(full.tokens.filter { $0.side == .away }.count == 11)
        #expect(full.tokens.filter { $0.kind == .ball }.count == 1)
        let steps = try #require(full.phases.first?.steps)
        #expect(steps.count == 6)
        #expect(steps.allSatisfy { $0.positions.count == 23 })
    }

    @Test func encodedJSONUsesFormatKeys() throws {
        let data = try TacticFormat.encode(Fixtures.tactic("overlap-left"))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["schemaVersion", "id", "title", "pitch", "sides", "tokens", "phases", "app"])
        #expect(object["schemaVersion"] as? Int == 1)

        let side = try #require((object["sides"] as? [[String: Any]])?.first)
        #expect(Set(side.keys) == ["id", "name", "colour"])  // rendering is derived, never written

        let token = try #require((object["tokens"] as? [[String: Any]])?.first)
        #expect(Set(token.keys) == ["id", "kind", "side", "number", "roleID"])

        let phase = try #require((object["phases"] as? [[String: Any]])?.first)
        #expect(Set(phase.keys) == ["id", "name", "steps"])
        let steps = try #require(phase["steps"] as? [[String: Any]])
        #expect(Set(steps[1].keys) == ["id", "duration", "positions", "runs", "arrows", "note"])
        // Empty runs and arrows and a missing note are left out (D-45); a blank tactic's step shows it.
        let blank = try TacticFormat.encode(TacticFormat.decode(TacticDocument.emptyTactic()))
        let blankObject = try #require(JSONSerialization.jsonObject(with: blank) as? [String: Any])
        let blankStep = try #require(((blankObject["phases"] as? [[String: Any]])?.first?["steps"] as? [[String: Any]])?.first)
        #expect(Set(blankStep.keys) == ["id", "duration", "positions"])
        #expect(Set(steps[0].keys) == ["id", "duration", "positions", "arrows", "note"])
        let arrow = try #require((steps[0]["arrows"] as? [[String: Any]])?.first)
        #expect(Set(arrow.keys) == ["kind", "points"])
    }

    @Test func unknownKeysAreDroppedOnWrite() throws {
        let data = try TestTactics.patched(
            TestTactics.small(),
            replacing: "\"title\":\"Small\"",
            with: "\"title\":\"Small\",\"futureField\":{\"a\":1}"
        )
        let tactic = try TacticFormat.decode(data)
        let written = try #require(String(data: TacticFormat.encode(tactic), encoding: .utf8))
        #expect(!written.contains("futureField"))
    }
}
