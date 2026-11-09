import Testing
@testable import CenterSpot

/// D-98: the tag over a tapped player reads its name, else its position as a coach writes it.
struct PlayerTagTests {
    private func player(_ roleID: String?, name: String? = nil, side: Side.ID = .home) -> Token {
        Token(id: "p", kind: .player, side: side, number: 6, name: name, roleID: roleID)
    }

    @Test func everyRoleHasAPosition() {
        for role in Presets.shared.roles {
            #expect(Role.position(role.id, x: 0.2, side: .home) != nil, "\(role.id)")
        }
    }

    @Test func positionsReadAsCoachesWriteThem() {
        #expect(player("holding-midfielder").tag(at: Point(x: 0.5, y: 0.3)) == "CDM")
        #expect(player("central-midfielder").tag(at: Point(x: 0.4, y: 0.4)) == "CM")
        #expect(player("centre-back").tag(at: Point(x: 0.3, y: 0.2)) == "CB")
        #expect(player("striker").tag(at: Point(x: 0.5, y: 0.7)) == "ST")
        #expect(player("goalkeeper").tag(at: Point(x: 0.5, y: 0.05)) == "GK")
        #expect(player("shadow-striker").tag(at: Point(x: 0.5, y: 0.6)) == "CF")
    }

    /// Ours attack upward, so the left is low x; theirs attack downward, so their left is high x.
    @Test func sideComesFromWhereThePlayerStands() {
        #expect(player("full-back").tag(at: Point(x: 0.15, y: 0.25)) == "LB")
        #expect(player("full-back").tag(at: Point(x: 0.85, y: 0.25)) == "RB")
        #expect(player("winger").tag(at: Point(x: 0.85, y: 0.7)) == "RW")
        #expect(player("wing-back", side: .away).tag(at: Point(x: 0.15, y: 0.7)) == "RWB")
        #expect(player("winger", side: .away).tag(at: Point(x: 0.85, y: 0.3)) == "LW")
    }

    @Test func aNameTakesThePositionsPlace() {
        #expect(player("centre-back", name: "Ade").tag(at: Point(x: 0.4, y: 0.2)) == "Ade")
        #expect(player("centre-back", name: "  ").tag(at: Point(x: 0.4, y: 0.2)) == "CB")
        #expect(player(nil).tag(at: Point(x: 0.4, y: 0.2)) == nil)
        #expect(Token(id: "b", kind: .ball).tag(at: Point(x: 0.5, y: 0.5)) == nil)
    }
}
