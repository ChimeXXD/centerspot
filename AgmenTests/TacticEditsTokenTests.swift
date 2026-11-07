import Foundation
import Testing
@testable import Agmen

/// Adding, removing and editing tokens (D-55, UI-BRIEF §4.3).
struct TacticEditsTokenTests {
    private func everyStep(_ t: Tactic) -> [Step] { t.phases.flatMap(\.steps) }

    @Test func ourPlayerTakesTheNextFreeNumberAndStandsOnTheCentreSpotInEveryStep() throws {
        var t = TestTactics.small()  // home has 4 and 9
        let id = try #require(TacticEdits.addToken(.ourPlayer, in: &t))
        let token = try #require(t.tokens.first { $0.id == id })
        #expect(token.kind == .player && token.side == .home && token.number == 1)
        #expect(everyStep(t).allSatisfy { $0.positions[id] == .centre })
        let second = try #require(TacticEdits.addToken(.ourPlayer, in: &t))
        #expect(t.tokens.first { $0.id == second }?.number == 2)
        #expect(Set(t.tokens.map(\.id)).count == t.tokens.count)
    }

    @Test func theirPlayerIsAnAwayPlayerWithTheirOwnNumbering() throws {
        var t = TestTactics.small()  // away has 5
        let id = try #require(TacticEdits.addToken(.theirPlayer, in: &t))
        let token = try #require(t.tokens.first { $0.id == id })
        #expect(token.side == .away && token.number == 1)
        #expect(t.tokens.filter { $0.side == .home }.count == 2)
    }

    @Test func onlyOneBall() throws {
        var t = TestTactics.small()  // already has a ball
        #expect(TacticEdits.addToken(.ball, in: &t) == nil)
        t.tokens.removeAll { $0.kind == .ball }
        let id = try #require(TacticEdits.addToken(.ball, in: &t))
        #expect(t.tokens.first { $0.id == id }?.kind == .ball)
        #expect(TacticEdits.addToken(.ball, in: &t) == nil)
    }

    @Test func conesCanRepeatWithUniqueIDs() throws {
        var t = TestTactics.small()
        let a = try #require(TacticEdits.addToken(.cone, in: &t))
        let b = try #require(TacticEdits.addToken(.cone, in: &t))
        #expect(a != b)
        #expect(t.tokens.filter { $0.kind == .cone }.count == 2)
    }

    @Test func addingRespectsTheThirtyTokenCap() {
        var t = TestTactics.small()
        while t.tokens.count < TacticFormat.maxTokens { _ = TacticEdits.addToken(.cone, in: &t) }
        #expect(TacticEdits.addToken(.ourPlayer, in: &t) == nil)
        #expect(t.tokens.count == 30)
    }

    @Test func deleteTokenRemovesItsPositionsAndRuns() {
        var t = TestTactics.small()
        TacticEdits.deleteToken("h9", in: &t)
        #expect(!t.tokens.contains { $0.id == "h9" })
        #expect(everyStep(t).allSatisfy { $0.positions["h9"] == nil && $0.runs["h9"] == nil })
        #expect(t.tokens.count == 3)
    }

    @Test func nameIsTrimmedTruncatedAndEmptyClears() {
        var t = TestTactics.small()
        TacticEdits.setName("  Ade  ", token: "h4", in: &t)
        #expect(t.tokens[0].name == "Ade")
        TacticEdits.setName(String(repeating: "x", count: 40), token: "h4", in: &t)
        #expect(t.tokens[0].name?.count == 24)
        TacticEdits.setName("", token: "h4", in: &t)
        #expect(t.tokens[0].name == nil)
    }

    @Test(arguments: [(7, 7), (0, 0), (99, 99), (150, 99), (-4, 0)])
    func numberIsClamped(input: Int, expected: Int) {
        var t = TestTactics.small()
        TacticEdits.setNumber(input, token: "h4", in: &t)
        #expect(t.tokens[0].number == expected)
    }

    @Test func roleAndSideChange() {
        var t = TestTactics.small()
        TacticEdits.setRole("full-back", token: "h4", in: &t)
        TacticEdits.setSide(.away, token: "h4", in: &t)
        #expect(t.tokens[0].roleID == "full-back" && t.tokens[0].side == .away)
        TacticEdits.setSide(.away, token: "ball", in: &t)
        #expect(t.tokens[3].side == nil, "only players have a side")
    }

    @Test func editedTacticsStillPassTheImporter() throws {
        var t = try Fixtures.tactic("overlap-left")
        _ = TacticEdits.addStep(after: 1, in: &t)
        TacticEdits.moveStep(from: 4, to: 0, in: &t)
        _ = TacticEdits.addToken(.cone, in: &t)
        TacticEdits.deleteToken("h9", in: &t)
        _ = TacticEdits.deleteStep(at: 2, in: &t)
        let reread = try TacticFormat.decode(TacticFormat.encode(t))
        #expect(reread.tokens == t.tokens)
        #expect(reread.phases[0].steps.map(\.id) == t.phases[0].steps.map(\.id))
    }
}
