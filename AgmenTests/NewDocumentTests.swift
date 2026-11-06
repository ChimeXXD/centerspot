import Foundation
import Testing
@testable import Agmen

/// Day 0 smoke tests: a new document is a valid v1 `.tactic` (docs/FORMAT.md), and the fixtures ship with the tests.
struct NewDocumentTests {
    @Test func newDocumentIsVersionOneTactic() throws {
        let document = TacticDocument()
        let object = try #require(JSONSerialization.jsonObject(with: document.encoded()) as? [String: Any])

        #expect(object["schemaVersion"] as? Int == 1)
        let sides = try #require(object["sides"] as? [[String: Any]])
        #expect(sides.compactMap { $0["id"] as? String } == ["home", "away"])
        let tokens = try #require(object["tokens"] as? [Any])
        #expect(tokens.isEmpty)  // an empty board is valid (D-27)
        let phases = try #require(object["phases"] as? [[String: Any]])
        #expect(phases.map { $0["id"] as? String } == ["main"])
        let steps = try #require(phases.first?["steps"] as? [Any])
        #expect(steps.count == 1)
    }

    @Test func newDocumentsHaveDistinctIDs() throws {
        let first = try #require(JSONSerialization.jsonObject(with: TacticDocument().encoded()) as? [String: Any])
        let second = try #require(JSONSerialization.jsonObject(with: TacticDocument().encoded()) as? [String: Any])
        #expect(first["id"] as? String != second["id"] as? String)
    }

    @Test func heroFixtureIsBundled() throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "overlap-left", withExtension: "tactic"))
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let phases = try #require(object["phases"] as? [[String: Any]])
        let steps = try #require(phases.first?["steps"] as? [Any])
        #expect(steps.count == 5)  // the hero move (D-29)
        #expect((object["tokens"] as? [Any])?.count == 17)  // 11 home, 5 away, ball (D-33)
    }
}

private final class BundleToken {}
