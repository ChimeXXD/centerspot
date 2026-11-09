import Foundation
import Testing
@testable import CenterSpot

/// Presets load from the bundled presets/*.json (D-14), and applying a formation keeps names and numbers.
struct PresetTests {
    let presets = try! Presets.bundled()

    /// D-14 plus D-63's common FC/FM set: 18 eleven-a-side shapes, four 7-a-side and four 5-a-side.
    static let expectedIDs: [Pitch.Kind: [String]] = [
        .full: ["4-3-3", "4-2-3-1", "4-4-2", "4-1-4-1", "4-2-1-3", "4-1-2-1-2", "4-3-2-1", "4-4-1-1", "4-5-1", "4-2-2-2",
                "4-3-1-2", "3-5-2", "3-4-3", "3-4-2-1", "3-4-1-2", "5-3-2", "5-4-1", "5-2-1-2"],
        .sevenASide: ["7-2-3-1", "7-3-2-1", "7-3-3", "7-2-1-2-1"],
        .fiveASide: ["5-1-2-1", "5-2-2", "5-2-1-1", "5-1-1-2"],
    ]

    @Test func everyFormationAndTwentyTwoRolesLoad() {
        for (kind, ids) in Self.expectedIDs {
            #expect(presets.formations.filter { $0.pitch == kind }.map(\.id) == ids, "\(kind)")
        }
        #expect(presets.formations.count == 26)
        #expect(Set(presets.formations.map(\.id)).count == presets.formations.count, "ids unique")
        #expect(Set(presets.formations.map(\.name)).count == presets.formations.count, "names unique")
        #expect(presets.roles.count == 22)
    }

    /// Names are the plain numbers (D-13, D-63); smaller pitches say which pitch.
    @Test func namesArePlainNumbers() {
        for f in presets.formations {
            let shape = f.name.replacingOccurrences(of: " (7-a-side)", with: "").replacingOccurrences(of: " (5-a-side)", with: "")
            #expect(shape.allSatisfy { $0.isNumber || $0 == "-" }, "\(f.id): \(f.name)")
            let lines = shape.split(separator: "-").compactMap { Int($0) }
            #expect(lines.reduce(0, +) + 1 == f.slots.count, "\(f.id): the lines add up to the outfield players")
        }
    }

    @Test func everySlotIsValid() {
        let roleIDs = Set(presets.roles.map(\.id))
        for f in presets.formations {
            #expect(f.slots.count == ["full": 11, "sevenASide": 7, "fiveASide": 5][f.pitch.rawValue], "\(f.id)")
            #expect(Set(f.slots.map(\.number)).count == f.slots.count, "\(f.id): numbers unique")
            for s in f.slots {
                #expect(roleIDs.contains(s.roleID), "\(f.id): \(s.roleID)")
                #expect((1...11).contains(s.number), "\(f.id): \(s.number)")
                #expect((0...1).contains(s.point.x) && (0...1).contains(s.point.y), "\(f.id): \(s.number)")
            }
        }
    }

    /// No two discs touch: centres at least 2.6 disc radii apart on the drawn pitch (y scaled by its aspect).
    @Test func noTwoSlotsOverlap() {
        let minimum = 2.6 * Double(BoardGeometry.tokenRadiusRatio)
        for f in presets.formations {
            let aspect = f.pitch.size.length / f.pitch.size.width
            for (i, a) in f.slots.enumerated() {
                for b in f.slots.dropFirst(i + 1) {
                    let d = hypot(a.point.x - b.point.x, (a.point.y - b.point.y) * aspect)
                    #expect(d >= minimum, "\(f.id): \(a.number) and \(b.number) are \(d) apart")
                }
            }
        }
    }

    /// Roles sit at their line's height: one keeper on the goal line, every defender behind every attacker, and the
    /// lines' average heights rise keeper < defence < midfield < attack.
    @Test func rolesMatchTheirSlotsHeight() throws {
        for f in presets.formations {
            var heights: [Role.Line: [Double]] = [:]
            for s in f.slots {
                let role = try #require(presets.role(s.roleID), "\(f.id): \(s.roleID)")
                heights[role.line, default: []].append(s.point.y)
            }
            #expect(heights[.gk] ?? [] == [0.06], "\(f.id): one keeper on the goal line")
            let outfield = f.slots.map(\.point.y).filter { $0 != 0.06 }
            #expect(outfield.allSatisfy { (0.15...0.75).contains($0) }, "\(f.id): \(outfield)")
            if let deepestAttacker = heights[.att]?.min(), let highestDefender = heights[.def]?.max() {
                #expect(highestDefender < deepestAttacker, "\(f.id)")
            }
            let means = [Role.Line.gk, .def, .mid, .att].compactMap { line in
                heights[line].map { $0.reduce(0, +) / Double($0.count) }
            }
            #expect(means == means.sorted() && Set(means).count == means.count, "\(f.id): \(means)")
        }
    }

    /// FormationMatch can tell every pair apart: one shape applied to a blank board is never within tolerance of
    /// another shape on the same pitch, so the tag under the pitch is never ambiguous.
    @Test func everyShapeIsOutsideEveryOtherShapesTolerance() {
        for a in presets.formations {
            let applied = a.apply(to: TacticDocument.blank(), stepIndex: 0)
            for b in presets.formations where b.pitch == a.pitch && b.id != a.id {
                #expect(FormationMatch.formation(of: applied, in: [b]) == nil, "\(a.id) reads as \(b.id)")
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

    /// D-83: a smaller shape removes the home players left over, from every step; the other side and the ball stay.
    @Test func fiveASideSwitchesThePitchAndRemovesTheExtraPlayers() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let f = try #require(presets.formations.first { $0.pitch == .fiveASide })
        let after = f.apply(to: hero, stepIndex: 0)
        #expect(after.pitch.kind == .fiveASide)
        let home = { (t: Tactic) in t.tokens.filter { $0.kind == .player && $0.side == .home } }
        #expect(home(after).count == f.slots.count)
        #expect(after.tokens.filter { $0.side != .home } == hero.tokens.filter { $0.side != .home })
        let gone = Set(home(hero).map(\.id)).subtracting(home(after).map(\.id))
        #expect(gone.count == home(hero).count - f.slots.count)
        for step in after.phases[0].steps {
            #expect(gone.allSatisfy { step.positions[$0] == nil && step.runs[$0] == nil })
        }
        #expect(Formation.extraPlayers(in: hero, for: f) == gone.count)
        // Still a valid file.
        #expect(try TacticFormat.decode(TacticFormat.encode(after)).tokens.count == after.tokens.count)
    }

    /// A shape with as many slots as players removes no one.
    @Test func aSameSizeShapeRemovesNoOne() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let f = try #require(presets.formation("4-4-2"))
        #expect(Formation.extraPlayers(in: hero, for: f) == 0)
        #expect(f.apply(to: hero, stepIndex: 0).tokens.count == hero.tokens.count)
    }

    /// D-83: an arrow drawn from a removed player goes with them; one from a player who stays is kept.
    @Test func arrowsFromRemovedPlayersGo() throws {
        var hero = try Fixtures.tactic("overlap-left")
        let f = try #require(presets.formations.first { $0.pitch == .fiveASide })
        let kept = Set(f.apply(to: hero, stepIndex: 0).tokens.map(\.id))
        let home = hero.tokens.filter { $0.kind == .player && $0.side == .home }
        let leaving = try #require(home.first { !kept.contains($0.id) })
        let staying = try #require(home.first { kept.contains($0.id) })
        let last = hero.phases[0].steps.count - 1
        let positions = hero.phases[0].steps[last].positions
        let gone = Arrow(kind: .pass, points: [try #require(positions[leaving.id]), Point(x: 0.5, y: 0.5)])
        let stays = Arrow(kind: .run, points: [try #require(positions[staying.id]), Point(x: 0.4, y: 0.6)])
        hero.phases[0].steps[last].arrows = [gone, stays]
        let after = f.apply(to: hero, stepIndex: 0)
        #expect(after.phases[0].steps[last].arrows == [stays])
    }
}
