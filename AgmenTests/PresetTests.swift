import Foundation
import Testing
@testable import Agmen

/// Presets load from the bundled presets/*.json (D-14), and applying a formation keeps names and numbers.
struct PresetTests {
    let presets = try! Presets.bundled()

    @Test func twelveFormationsAndTwentyTwoRolesLoad() {
        #expect(presets.formations.count == 12)
        #expect(presets.formations.filter { $0.pitch == .full }.count == 8)
        #expect(presets.formations.filter { $0.pitch == .sevenASide }.count == 2)
        #expect(presets.formations.filter { $0.pitch == .fiveASide }.count == 2)
        #expect(presets.roles.count == 22)
        #expect(Set(presets.formations.map(\.id)).count == 12)
    }

    @Test func everySlotIsValid() {
        let roleIDs = Set(presets.roles.map(\.id))
        for f in presets.formations {
            #expect(f.slots.count == ["full": 11, "sevenASide": 7, "fiveASide": 5][f.pitch.rawValue], "\(f.id)")
            #expect(Set(f.slots.map(\.number)).count == f.slots.count, "\(f.id): numbers unique")
            for s in f.slots {
                #expect(roleIDs.contains(s.roleID), "\(f.id): \(s.roleID)")
                #expect((0...1).contains(s.point.x) && (0...1).contains(s.point.y), "\(f.id): \(s.number)")
            }
        }
    }

    @Test func applyingAFormationKeepsNamesAndNumbers() throws {
        var hero = try Fixtures.tactic("overlap-left")
        hero.tokens[1].name = "Ade"  // h3
        let target = try #require(presets.formation("4-2-3-1"))
        let after = target.apply(to: hero, stepIndex: 0)

        let home = { (t: Tactic) in t.tokens.filter { $0.side == .home } }
        #expect(home(after).map(\.id) == home(hero).map(\.id))
        #expect(home(after).map(\.number) == home(hero).map(\.number))
        #expect(home(after).map(\.name) == home(hero).map(\.name))
        // Each home player now stands on a 4-2-3-1 slot, matched by shirt number.
        for token in home(after) {
            let slot = try #require(target.slots.first { $0.number == token.number })
            #expect(after.phases[0].steps[0].positions[token.id] == slot.point, "\(token.id)")
            #expect(token.roleID == slot.roleID)
        }
    }

    @Test func onlyTheEditedStepMovesAndTheOtherSideStays() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let after = try #require(presets.formation("4-4-2")).apply(to: hero, stepIndex: 2)
        #expect(after.phases[0].steps[0] == hero.phases[0].steps[0])
        #expect(after.phases[0].steps[4] == hero.phases[0].steps[4])
        for id in hero.tokens.filter({ $0.side != .home }).map(\.id) {
            #expect(after.phases[0].steps[2].positions[id] == hero.phases[0].steps[2].positions[id], "\(id)")
        }
    }

    @Test func aBlankBoardGetsAFullTeam() throws {
        let blank = try TacticFormat.decode(TacticDocument.emptyTactic())
        let f = try #require(presets.formation("4-3-3"))
        let after = f.apply(to: blank, stepIndex: 0)
        let players = after.tokens.filter { $0.kind == .player && $0.side == .home }
        #expect(players.count == 11)
        #expect(Set(players.compactMap(\.number)) == Set(f.slots.map(\.number)))
        #expect(Set(after.tokens.map(\.id)).count == after.tokens.count)
        for step in after.phases[0].steps { #expect(players.allSatisfy { step.positions[$0.id] != nil }) }
        // The result is still a valid file.
        let reread = try TacticFormat.decode(TacticFormat.encode(after))
        #expect(reread.tokens.count == after.tokens.count)
    }

    @Test func fiveASideSwitchesThePitchAndExtraPlayersStayPut() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let f = try #require(presets.formations.first { $0.pitch == .fiveASide })
        let after = f.apply(to: hero, stepIndex: 0)
        #expect(after.pitch.kind == .fiveASide)
        let before = hero.phases[0].steps[0].positions, now = after.phases[0].steps[0].positions
        let moved = hero.tokens.filter { $0.side == .home && before[$0.id] != now[$0.id] }
        #expect(moved.count <= 5)
        #expect(after.tokens.count == hero.tokens.count)
    }
}
