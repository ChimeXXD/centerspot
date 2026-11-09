import Foundation

/// Builds a scenario's board from a shape (D-94), by the rules in `mockup/scenarios.js`, step for step, so the app sets
/// up exactly what the approved tiles show (`ScenarioTests` checks it against the mockup's own output). Points are
/// rounded to 0.001 and kept 0.02 inside the lines, as the mockup does.
extension Scenario {
    /// The board for this scenario with our `formation`, attacking (we have the ball) or not; nil when the opponent's
    /// shape is missing from the presets.
    func build(with formation: Formation, attacking: Bool) -> ScenarioBoard? {
        guard let opponent = Presets.shared.formation(formation.pitch.scenarioOpponent) else { return nil }
        return ScenarioBuilder.build(self, home: formation, away: opponent, attacking: attacking)
    }
}

extension Scenario {
    /// "Use <scenario>" (D-94): the pitch takes the shape's size, both sides take their places on `stepIndex` as
    /// `Formation.place` does (names stay by shirt number; others leave from every step, with their arrows), and the
    /// ball goes to its spot, added if there is none. The step starts clean: its arrows and runs began where the old
    /// players stood. Unchanged when the opponent's shape is missing.
    func apply(to tactic: Tactic, formation: Formation, attacking: Bool, stepIndex: Int, phaseIndex: Int = 0) -> Tactic {
        guard tactic.phases.indices.contains(phaseIndex), tactic.phases[phaseIndex].steps.indices.contains(stepIndex),
              let board = build(with: formation, attacking: attacking) else { return tactic }
        var result = tactic
        result.pitch.kind = formation.pitch
        result.phases[phaseIndex].steps[stepIndex].arrows = []
        result.phases[phaseIndex].steps[stepIndex].runs = [:]
        // The side that loses the most players goes first, so its leavers free room under the token cap before the
        // other side's newcomers need it.
        func surplus(_ side: Side.ID, _ players: [ScenarioBoard.Player]) -> Int {
            result.tokens.count(where: { $0.kind == .player && $0.side == side }) - players.count
        }
        let sides = [(Side.ID.home, board.home), (.away, board.away)].sorted { surplus($0.0, $0.1) > surplus($1.0, $1.1) }
        for (side, players) in sides {
            Formation.place(players.map { ($0.number, $0.roleID, $0.point) }, side: side, in: &result, stepIndex: stepIndex,
                            phaseIndex: phaseIndex)
        }
        if let ball = result.tokens.first(where: { $0.kind == .ball }) {
            result.phases[phaseIndex].steps[stepIndex].positions[ball.id] = board.ball
        } else if let id = TacticEdits.addToken(.ball, in: &result) {
            for p in result.phases.indices {
                for s in result.phases[p].steps.indices { result.phases[p].steps[s].positions[id] = board.ball }
            }
        }
        return result
    }
}

enum ScenarioBuilder {
    /// A shape's player where a rule put them: their slot (number, role, group, place in the shape) and `p`.
    struct Placed {
        let number: Int
        let roleID: String
        let group: String
        let slot: Point
        var p: Point
    }

    static func build(_ scenario: Scenario, home: Formation, away: Formation, attacking: Bool) -> ScenarioBoard {
        let ours = slots(of: home), theirs = slots(of: away)
        let on = attacking ? ours : theirs, off = attacking ? theirs : ours
        // Everything is worked out in the frame of the side on the ball; the other side's frame is it turned round.
        var onPlaced: [Placed], offPlaced: [Placed], ball: Point

        switch scenario.build {
        case let .team(onPhase, offPhase, carriedBy, onShift, offShift, press):
            onPlaced = inPhase(on, onPhase, shiftX: onShift)
            ball = carrier(onPlaced, carriedBy).p
            let ballThere = mirror(ball)
            offPlaced = inPhase(off, offPhase, focus: press ? ballThere : nil, pull: press ? 0.3 : 0)
            if offShift != 0 {
                offPlaced = offPlaced.map { s in
                    var s = s
                    if s.group != "GK" { s.p = pt(s.p.x + offShift, s.p.y) }
                    return s
                }
            }
        case let .small(_, m, at, support, who, vs, keeper, surround):
            let game = smallSided(at: at, support: support, defenders: m, surround: surround)
            onPlaced = pick(on, spots: game.attack, phase: .finalThird, prefs: who)
            offPlaced = pick(off, spots: game.defend.map(mirror), phase: .lowBlock, prefs: vs)
            if keeper, let gk = off.first(where: { $0.group == "GK" }) {
                var gk = gk
                gk.p = pt(0.5, 0.03)
                offPlaced.append(gk)
            }
            ball = game.attack[0]
        case let .setPiece(kind):
            let set = setPiece(kind)
            onPlaced = fill(on, spots: set.take)
            offPlaced = fill(off, spots: set.face.map { ($0.groups, 1 - $0.x, 1 - $0.y) })
            ball = pt(set.ball.x, set.ball.y)
        case .kickOff:
            onPlaced = kickOff(on)
            offPlaced = kickOff(off)
            let takers = onPlaced.indices.filter { ["ST", "AM", "CM"].contains(onPlaced[$0].group) }
            // The highest of them (the first, where level) stands over the ball.
            if let taker = takers.max(by: { onPlaced[$0].p.y < onPlaced[$1].p.y || (onPlaced[$0].p.y == onPlaced[$1].p.y && $0 > $1) }) {
                onPlaced[taker].p = pt(0.5, 0.49)
            }
            ball = pt(0.5, 0.5)
        }

        // To the board (we attack up): the side on the ball's frame is ours when attacking, else turned round.
        func players(_ placed: [Placed], turned: Bool) -> [ScenarioBoard.Player] {
            placed.map { ScenarioBoard.Player(number: $0.number, roleID: $0.roleID, point: turned ? mirror($0.p) : $0.p) }
        }
        return ScenarioBoard(
            home: attacking ? players(onPlaced, turned: false) : players(offPlaced, turned: false),
            away: attacking ? players(offPlaced, turned: true) : players(onPlaced, turned: true),
            ball: attacking ? ball : mirror(ball)
        )
    }

    // MARK: Points

    static func round(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }
    static func pt(_ x: Double, _ y: Double) -> Point {
        Point(x: round(x.clamped(to: 0.02...0.98)), y: round(y.clamped(to: 0.02...0.98)))
    }
    static func mirror(_ p: Point) -> Point { Point(x: round(1 - p.x), y: round(1 - p.y)) }

    /// A pitch is about 0.65 as wide as long, so distances weigh across less than along.
    static func distance(_ a: Point, _ b: Point) -> Double { hypot((a.x - b.x) * 0.65, a.y - b.y) }

    /// The index of the point nearest `p` (the first where level: within 1e-9, so mirror-image players tie the same
    /// way here as in the mockup's JavaScript).
    static func nearest(_ points: [Point], to p: Point) -> Int {
        var best = 0
        for i in points.indices where distance(points[i], p) < distance(points[best], p) - 1e-9 { best = i }
        return best
    }

    // MARK: Groups and phases

    /// Every role in presets/roles.json falls in one of nine groups.
    static let groups: [String: String] = [
        "goalkeeper": "GK", "sweeper-keeper": "GK", "centre-back": "CB", "ball-playing-centre-back": "CB",
        "full-back": "FB", "inverted-full-back": "FB", "wing-back": "FB",
        "holding-midfielder": "DM", "deep-playmaker": "DM", "central-midfielder": "CM", "box-to-box": "CM",
        "wide-midfielder": "WM", "attacking-midfielder": "AM", "advanced-playmaker": "AM", "free-role": "AM",
        "winger": "W", "inside-forward": "W", "striker": "ST", "shadow-striker": "ST", "target-forward": "ST",
        "false-nine": "ST", "pressing-forward": "ST",
    ]

    static func slots(of formation: Formation) -> [Placed] {
        formation.slots.map {
            Placed(number: $0.number, roleID: $0.roleID, group: groups[$0.roleID] ?? "CM", slot: $0.point, p: $0.point)
        }
    }

    /// A phase: lines at y' = a + b·y, the width about the middle times w, the keeper at a fixed height, and some
    /// groups moved further (dy) or wider (wx).
    struct PhaseRule {
        let a, b, w, gk: Double
        var g: [String: (dy: Double, wx: Double)] = [:]
    }

    static func rule(_ phase: Scenario.Phase) -> PhaseRule {
        switch phase {
        case .buildUp: PhaseRule(a: 0.02, b: 0.74, w: 1.05, gk: 0.05, g: ["CB": (-0.04, 1.75), "FB": (0.1, 1.15), "DM": (-0.04, 1)])
        case .midfield: PhaseRule(a: 0.12, b: 0.8, w: 1.05, gk: 0.1, g: ["FB": (0.1, 1.1), "CB": (0, 1.25)])
        case .finalThird:
            PhaseRule(a: 0.26, b: 0.7, w: 1.0, gk: 0.16,
                      g: ["FB": (0.22, 1.12), "CB": (0, 1.3), "W": (0.04, 1.15), "WM": (0.12, 1.15)])
        case .counter: PhaseRule(a: 0.12, b: 0.86, w: 1.1, gk: 0.08, g: ["W": (0.08, 1.2), "ST": (0.06, 1), "FB": (0.04, 1)])
        case .justWon: PhaseRule(a: 0.22, b: 0.7, w: 0.95, gk: 0.14, g: ["FB": (0.12, 1)])
        case .highPress: PhaseRule(a: 0.3, b: 0.62, w: 0.95, gk: 0.14, g: ["ST": (0.04, 1), "W": (0.04, 1.05)])
        case .midBlock: PhaseRule(a: 0.14, b: 0.5, w: 0.78, gk: 0.06)
        case .lowBlock: PhaseRule(a: 0.05, b: 0.36, w: 0.72, gk: 0.03, g: ["W": (-0.04, 1), "WM": (-0.03, 1)])
        case .caught: PhaseRule(a: 0.26, b: 0.7, w: 1.0, gk: 0.16, g: ["FB": (0.2, 1.12)])
        case .counterPress: PhaseRule(a: 0.24, b: 0.68, w: 0.85, gk: 0.15)
        }
    }

    /// A shape in a phase, in its own frame (attacking up), squeezed toward `focus` by `pull` (0…1). A shift across
    /// leaves the far touchline's player wide (the switch's free winger).
    static func inPhase(_ slots: [Placed], _ phase: Scenario.Phase, focus: Point? = nil, pull: Double = 0,
                        shiftX: Double = 0) -> [Placed] {
        let r = rule(phase)
        return slots.map { s in
            var s = s
            if s.group == "GK" {
                s.p = pt(0.5, r.gk)
                return s
            }
            let g = r.g[s.group] ?? (0, 1)
            var x = 0.5 + (s.slot.x - 0.5) * r.w * g.wx + (s.slot.x > 0.75 ? 0 : shiftX)
            var y = r.a + r.b * s.slot.y + g.dy
            if let focus {
                x += (focus.x - x) * pull
                y += (focus.y - y) * pull
            }
            s.p = pt(x, y)
            return s
        }
    }

    /// Where the ball is in each team shape (the side on it's frame); the outfield player nearest carries it.
    static func carrier(_ placed: [Placed], _ at: Scenario.BallAt) -> Placed {
        let spot: Point
        switch at {
        case .keeper: return placed.first { $0.group == "GK" } ?? placed[0]
        case .deep: spot = Point(x: 0.5, y: 0.36)
        case .leftWide: spot = Point(x: 0.08, y: 0.72)
        case .central: spot = Point(x: 0.5, y: 0.42)
        }
        let outfield = placed.filter { $0.group != "GK" }
        guard !outfield.isEmpty else { return placed[0] }
        return outfield[nearest(outfield.map(\.p), to: spot)]
    }

    // MARK: Small-sided

    /// Attackers round the ball, defenders goal-side of them, in the attackers' frame (attacking up).
    static func smallSided(at: Point, support: [Point], defenders m: Int, surround: Bool) -> (attack: [Point], defend: [Point]) {
        let bx = at.x, by = at.y
        let inward: Double = bx < 0.4 ? 1 : bx > 0.6 ? -1 : 1
        let attack = [pt(bx, by)] + support.map { pt(bx + $0.x * inward, by + $0.y) }
        let goal = Point(x: 0.5, y: 1)
        func step(_ from: Point, _ toward: Point, _ d: Double) -> Point {
            let vx = (toward.x - from.x) * 0.65, vy = toward.y - from.y
            let length = hypot(vx, vy) == 0 ? 1 : hypot(vx, vy)
            return pt(from.x + vx / length * d / 0.65, from.y + vy / length * d)
        }
        var defend: [Point] = []
        for i in 0..<m {
            if surround, i > 0 {
                let side: Double = i % 2 == 1 ? -1 : 1
                defend.append(pt(bx + side * 0.09, by - 0.02 + 0.04 * Double((i - 1) / 2)))
            } else if i < attack.count {
                defend.append(step(attack[i], goal, i == 0 ? 0.05 : 0.06))
            } else {
                // Spare defenders cover the space behind, between the ball and goal.
                let k = i - attack.count, side: Double = k % 2 == 1 ? -1 : 1
                defend.append(pt(0.5 + side * 0.1 * Double(1 + k / 2) * 0.6 + (bx - 0.5) * 0.4, min(0.9, by + 0.14)))
            }
        }
        return (attack, defend)
    }

    /// Who plays each spot: for each, the nearest player (where they stand in `phase`) of the first listed group with
    /// one left (`prefs[i]`, e.g. "W,WM"), else the nearest player left. Keepers excluded.
    static func pick(_ slots: [Placed], spots: [Point], phase: Scenario.Phase, prefs: [String]) -> [Placed] {
        var placed = inPhase(slots, phase).filter { $0.group != "GK" }
        return spots.enumerated().map { k, spot in
            var pool = placed
            let listed = k < prefs.count ? prefs[k].split(separator: ",").map(String.init) : []
            for g in listed {
                let of = placed.filter { $0.group == g }
                if !of.isEmpty {
                    pool = of
                    break
                }
            }
            var chosen = pool[nearest(pool.map(\.p), to: spot)]
            placed.removeAll { $0.number == chosen.number && $0.roleID == chosen.roleID }
            chosen.p = spot
            return chosen
        }
    }

    // MARK: Set pieces and kick-off

    typealias Spot = (groups: String, x: Double, y: Double)

    /// Fills `spots` from `slots`: each takes the first unused slot of a listed group (in the listed order), else the
    /// nearest unused one. A smaller team fills the spots in order until it runs out.
    static func fill(_ slots: [Placed], spots: [Spot]) -> [Placed] {
        var free = slots, out: [Placed] = []
        for spot in spots {
            guard !free.isEmpty else { break }
            let at = Point(x: spot.x, y: spot.y)
            var index: Int?
            for g in spot.groups.split(separator: ",").map(String.init) {
                index = free.firstIndex { $0.group == g }
                if index != nil { break }
            }
            let i = index ?? nearest(free.map(\.slot), to: at)
            var s = free.remove(at: i)
            s.p = pt(spot.x, spot.y)
            out.append(s)
        }
        return out
    }

    /// Each side in its own half, its shape squeezed into it.
    static func kickOff(_ slots: [Placed]) -> [Placed] {
        slots.map { s in
            var s = s
            s.p = s.group == "GK" ? pt(0.5, 0.05) : pt(0.5 + (s.slot.x - 0.5) * 0.95, min(0.47, 0.04 + s.slot.y * 0.62))
            return s
        }
    }

    struct SetPieceSpots {
        let take: [Spot]
        let face: [Spot]
        let ball: Point
    }

    /// The spots for the side taking it (`take`) and the other (`face`), in the taker's frame.
    static func setPiece(_ kind: Scenario.SetPiece) -> SetPieceSpots {
        switch kind {
        case .corner:
            SetPieceSpots(
                take: [("GK", 0.5, 0.12), ("CB", 0.56, 0.93), ("CB", 0.46, 0.9), ("ST", 0.42, 0.95), ("ST,W", 0.52, 0.88),
                       ("W,WM,AM", 0.01, 0.995), ("AM,CM", 0.34, 0.82), ("CM,DM", 0.6, 0.8), ("FB", 0.3, 0.62),
                       ("DM,FB", 0.55, 0.58), ("W,FB,WM", 0.82, 0.74)],
                face: [("GK", 0.5, 0.985), ("W,WM", 0.44, 0.99), ("CB", 0.48, 0.95), ("CB", 0.56, 0.95), ("FB", 0.4, 0.94),
                       ("FB", 0.62, 0.92), ("DM,CM", 0.47, 0.89), ("CM", 0.58, 0.87), ("AM,CM", 0.36, 0.84),
                       ("WM,W", 0.07, 0.95), ("ST", 0.5, 0.62)],
                ball: Point(x: 0.01, y: 0.995))
        case .freeKickEdge:
            SetPieceSpots(
                take: [("GK", 0.5, 0.16), ("AM,W", 0.47, 0.76), ("W,AM", 0.53, 0.75), ("ST", 0.4, 0.86), ("ST,CB", 0.6, 0.86),
                       ("CB", 0.56, 0.82), ("CM", 0.34, 0.74), ("CB,DM", 0.44, 0.6), ("FB", 0.2, 0.6), ("FB", 0.8, 0.62),
                       ("DM,CM", 0.58, 0.6)],
                face: [("GK", 0.48, 0.985), ("ST,W", 0.42, 0.81), ("AM,CM", 0.46, 0.81), ("CM,W", 0.5, 0.81),
                       ("CM,WM", 0.54, 0.81), ("CB", 0.42, 0.88), ("CB", 0.6, 0.88), ("FB", 0.32, 0.88), ("FB", 0.68, 0.87),
                       ("DM", 0.56, 0.84), ("WM,W", 0.22, 0.8)],
                ball: Point(x: 0.5, y: 0.75))
        case .freeKickWide:
            SetPieceSpots(
                take: [("GK", 0.5, 0.18), ("W,WM,AM", 0.86, 0.82), ("CB", 0.48, 0.88), ("CB", 0.58, 0.86), ("ST", 0.42, 0.9),
                       ("ST,W", 0.36, 0.84), ("AM,CM", 0.54, 0.78), ("CM", 0.4, 0.72), ("FB", 0.2, 0.62), ("DM,FB", 0.55, 0.6),
                       ("FB,W", 0.76, 0.66)],
                face: [("GK", 0.5, 0.985), ("W,WM", 0.84, 0.86), ("CB", 0.47, 0.91), ("CB", 0.57, 0.89), ("FB", 0.4, 0.92),
                       ("FB", 0.63, 0.9), ("DM,CM", 0.5, 0.86), ("CM", 0.44, 0.84), ("AM,CM", 0.58, 0.82), ("WM,W", 0.3, 0.8),
                       ("ST", 0.5, 0.6)],
                ball: Point(x: 0.86, y: 0.82))
        case .goalKick:
            SetPieceSpots(
                take: [("GK", 0.5, 0.03), ("CB", 0.36, 0.09), ("CB", 0.64, 0.09), ("FB", 0.08, 0.2), ("FB", 0.92, 0.2),
                       ("DM", 0.5, 0.24), ("CM,AM", 0.32, 0.36), ("CM,AM", 0.68, 0.36), ("W,WM", 0.12, 0.52), ("W,WM", 0.88, 0.52),
                       ("ST", 0.5, 0.56)],
                face: [("GK", 0.5, 0.86), ("ST", 0.42, 0.18), ("ST,AM", 0.58, 0.18), ("WM,W", 0.18, 0.28), ("WM,W", 0.82, 0.28),
                       ("CM", 0.42, 0.34), ("CM,DM", 0.58, 0.34), ("CB", 0.4, 0.56), ("CB", 0.6, 0.56), ("FB", 0.2, 0.5),
                       ("FB", 0.8, 0.5)],
                ball: Point(x: 0.44, y: 0.04))
        case .throwIn:
            SetPieceSpots(
                take: [("GK", 0.5, 0.2), ("FB,WM", 0.0, 0.66), ("W,WM", 0.1, 0.74), ("ST", 0.2, 0.8), ("AM,CM", 0.18, 0.62),
                       ("CM", 0.34, 0.66), ("DM", 0.36, 0.52), ("CB", 0.38, 0.4), ("CB", 0.62, 0.4), ("FB", 0.74, 0.5),
                       ("W,ST", 0.66, 0.78)],
                face: [("GK", 0.5, 0.97), ("FB", 0.1, 0.7), ("WM,W", 0.12, 0.6), ("CM", 0.24, 0.68), ("CB", 0.3, 0.82),
                       ("CB", 0.48, 0.84), ("FB", 0.64, 0.82), ("DM,CM", 0.3, 0.58), ("CM,AM", 0.44, 0.66), ("WM,W", 0.62, 0.66),
                       ("ST", 0.46, 0.5)],
                ball: Point(x: 0.0, y: 0.66))
        case .penalty:
            SetPieceSpots(
                take: [("ST", 0.5, 0.88), ("GK", 0.5, 0.1), ("CB", 0.38, 0.82), ("W", 0.3, 0.83), ("AM,CM", 0.62, 0.82),
                       ("W,WM", 0.7, 0.83), ("CM", 0.44, 0.8), ("CB,DM", 0.56, 0.79), ("FB", 0.34, 0.6), ("FB", 0.66, 0.6),
                       ("DM,CM", 0.5, 0.62)],
                face: [("GK", 0.5, 0.995), ("CB", 0.36, 0.83), ("CB", 0.64, 0.83), ("FB", 0.28, 0.82), ("FB", 0.72, 0.82),
                       ("DM,CM", 0.42, 0.79), ("CM", 0.58, 0.79), ("AM,CM", 0.47, 0.8), ("WM,W", 0.24, 0.78), ("WM,W", 0.76, 0.78),
                       ("ST", 0.5, 0.6)],
                ball: Point(x: 0.5, y: 0.895))
        }
    }
}
