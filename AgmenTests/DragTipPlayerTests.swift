import Testing
@testable import Agmen

/// D-82: the "Move a player" tip points at our number 7, never the keeper.
struct DragTipPlayerTests {
    private func player(_ id: String, _ side: Side.ID, _ number: Int?, role: String? = nil) -> Token {
        Token(id: id, kind: .player, side: side, number: number, roleID: role)
    }

    @Test func theExamplePointsAtOurSeven() throws {
        let tactic = try Fixtures.tactic("overlap-left")
        #expect(Onboarding.dragTipPlayer(in: tactic.tokens) == "h7")
    }

    /// Their 7 is not ours: it skips the away side.
    @Test func ourSevenNotTheirs() {
        let tokens = [player("a7", .away, 7), player("h1", .home, 1, role: "goalkeeper"), player("h7", .home, 7)]
        #expect(Onboarding.dragTipPlayer(in: tokens) == "h7")
    }

    /// With no 7, our first outfield player: never the keeper, by role or by the number 1.
    @Test func withoutASevenNeverTheKeeper() {
        let byRole = [player("k", .home, 13, role: "goalkeeper"), player("h4", .home, 4)]
        #expect(Onboarding.dragTipPlayer(in: byRole) == "h4")
        let byNumber = [player("h1", .home, 1), player("h5", .home, 5)]
        #expect(Onboarding.dragTipPlayer(in: byNumber) == "h5")
        let sweeper = [player("k", .home, 23, role: "sweeper-keeper"), player("h2", .home, 2)]
        #expect(Onboarding.dragTipPlayer(in: sweeper) == "h2")
    }

    /// A keeper who wears 7 is still the keeper.
    @Test func aKeeperInSevenIsSkipped() {
        let tokens = [player("k7", .home, 7, role: "goalkeeper"), player("h4", .home, 4)]
        #expect(Onboarding.dragTipPlayer(in: tokens) == "h4")
    }

    /// A board of only a keeper still gets the tip, on the keeper; an empty board gets none.
    @Test func fallsBackToAnyPlayer() {
        #expect(Onboarding.dragTipPlayer(in: [player("h1", .home, 1, role: "goalkeeper")]) == "h1")
        #expect(Onboarding.dragTipPlayer(in: []) == nil)
    }
}
