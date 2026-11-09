import Foundation

/// Every scenario as a ready-made move (D-96), by the rules in `mockup/scenario-motion.js`, step for step, so the app
/// sets up exactly the move the approved sample plays (`ScenarioMoveTests` checks it against the mockup's own output).
/// The scripts are read from `presets/scenario-moves.json`, which is written from the mockup, never typed twice.
///
/// The side on the ball follows its script, beat by beat (a beat is what happens between two steps); players are
/// named by role, so the script fits every shape. The other side reacts by rule after each beat: the nearest player
/// presses, one tracks each runner, the keeper sets, the rest slide with the ball (at a set piece they hold zones).
/// All of it in the attackers' frame (attacking up), turned to the board after.
enum ScenarioMotion {
    /// One step of a move: where everyone stands (shirt number, place), the ball, the arrows shown and the note.
    struct Step: Sendable, Equatable {
        struct Player: Sendable, Equatable {
            let number: Int
            let point: Point
        }

        let home: [Player]
        let away: [Player]
        let ball: Point
        let arrows: [Arrow]
        let note: String
        let duration: Double
    }

    // MARK: Building

    private static let goal = Point(x: 0.5, y: 1)
    private static func round(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }
    private static func onPitch(_ x: Double, _ y: Double) -> Point {
        Point(x: round(x.clamped(to: 0.02...0.98)), y: round(y.clamped(to: 0.02...0.98)))
    }
    private static func toward(_ from: Point, _ to: Point, _ d: Double) -> Point {
        let vx = (to.x - from.x) * 0.65, vy = to.y - from.y
        let length = hypot(vx, vy) == 0 ? 1 : hypot(vx, vy)
        return onPitch(from.x + vx / length * d / 0.65, from.y + vy / length * d)
    }
    private static func gap(_ a: Point, _ b: Point) -> Double { hypot((a.x - b.x) * 0.65, a.y - b.y) }

    /// A player in the build: their side (`attacker` is the side on the ball) and index there.
    private struct Ref: Hashable {
        let attacker: Bool
        let index: Int
    }

    private struct Man {
        let number: Int
        let group: String
        var p: Point
    }

    /// The move for `scenario` with our `formation`, attacking or not: the set-up step, then one step per beat. Nil when
    /// the scenario has no script or its board can't be built.
    /// `shirts` turns a shape's numbers into the numbers on the board's players for the notes (a player numbered 23
    /// who takes the 9's place is "23" in the notes); places, as the shape's numbers, are unchanged.
    static func build(_ scenario: Scenario, formation: Formation, attacking: Bool,
                      shirts: [Side.ID: [Int: Int]] = [:]) -> [Step]? {
        guard let script = scripts[scenario.id], let board = scenario.build(with: formation, attacking: attacking) else { return nil }
        // To the attackers' frame: when we defend, they attack down the board, so turn everything round (and back).
        func frame(_ p: Point) -> Point { attacking ? p : Point(x: round(1 - p.x), y: round(1 - p.y)) }
        func men(_ list: [ScenarioBoard.Player]) -> [Man] {
            list.map { Man(number: $0.number, group: ScenarioBuilder.groups[$0.roleID] ?? "CM", p: frame($0.point)) }
        }
        var att = men(attacking ? board.home : board.away)
        var def = men(attacking ? board.away : board.home)
        var ball = frame(board.ball)

        func point(_ r: Ref) -> Point { r.attacker ? att[r.index].p : def[r.index].p }
        func set(_ r: Ref, _ p: Point) { if r.attacker { att[r.index].p = p } else { def[r.index].p = p } }
        func nearestAttacker(to p: Point) -> Ref {
            var best = 0
            for i in att.indices where gap(att[i].p, p) < gap(att[best].p, p) { best = i }
            return Ref(attacker: true, index: best)
        }

        // The cast: aliases to players.
        var cast: [String: Ref] = [:]
        let keeper = def.firstIndex { $0.group == "GK" }.map { Ref(attacker: false, index: $0) }
        switch scenario.build {
        case .small:
            for i in att.indices { cast["A\(i)"] = Ref(attacker: true, index: i) }
            for (k, i) in def.indices.filter({ def[$0].group != "GK" }).enumerated() { cast["D\(k)"] = Ref(attacker: false, index: i) }
            if let keeper { cast["K"] = keeper }
        case .setPiece:
            for i in att.indices { cast["S\(i)"] = Ref(attacker: true, index: i) }
            if let keeper { cast["K"] = keeper }
        case .team, .kickOff:
            var taken = Set<Int>()
            for (alias, entry) in script.cast {
                if case .ball = entry {
                    let r = nearestAttacker(to: ball)
                    cast[alias] = r
                    taken.insert(r.index)
                }
            }
            for (alias, entry) in script.cast {
                guard case let .role(groups, side, fallback) = entry else { continue }
                let free = att.indices.filter { !taken.contains($0) }
                var pick: Int?
                for g in groups {
                    let of = free.filter { att[$0].group == g }
                    guard var best = of.first else { continue }
                    func key(_ i: Int) -> Double {
                        side == "left" ? att[i].p.x : side == "right" ? -att[i].p.x : abs(att[i].p.x - 0.5)
                    }
                    for i in of.dropFirst() where key(i) < key(best) - 1e-9 { best = i }
                    pick = best
                    break
                }
                if pick == nil {
                    let outfield = free.filter { att[$0].group != "GK" }
                    guard var best = outfield.first else { continue }
                    for i in outfield.dropFirst() where gap(att[i].p, fallback) < gap(att[best].p, fallback) - 1e-9 { best = i }
                    pick = best
                }
                if let pick {
                    cast[alias] = Ref(attacker: true, index: pick)
                    taken.insert(pick)
                }
            }
        }

        func say(_ text: String) -> String {
            var out = "", rest = Substring(text)
            while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
                out += rest[..<open]
                let alias = String(rest[rest.index(after: open)..<close])
                out += cast[alias].map { r in
                    let number = r.attacker ? att[r.index].number : def[r.index].number
                    let side: Side.ID = r.attacker == attacking ? .home : .away
                    return String(shirts[side]?[number] ?? number)
                } ?? alias
                rest = rest[rest.index(after: close)...]
            }
            out += rest
            return attacking ? out : "Their \(out)"
        }

        func snapshot(arrows: [Arrow], note: String, duration: Double) -> Step {
            let a = att.map { Step.Player(number: $0.number, point: frame($0.p)) }
            let d = def.map { Step.Player(number: $0.number, point: frame($0.p)) }
            return Step(home: attacking ? a : d, away: attacking ? d : a, ball: frame(ball),
                        arrows: arrows.map { Arrow(kind: $0.kind, points: $0.points.map(frame)) }, note: note, duration: duration)
        }

        var steps: [Step] = []
        var outOfIt: [Ref] = []
        var carrier: Ref = {
            if case .team = scenario.build, let car = cast["CAR"] { return car }
            return nearestAttacker(to: ball)
        }()
        let slide: (x: Double, y: Double) = if case .setPiece = scenario.build { (0.1, 0.1) } else { (0.45, 0.5) }

        // On Defending (D-97) the opponent runs the move but nobody on our side is beaten, and their last action (the
        // shot) never comes: our nearest player steps in and wins the ball (the keeper at a penalty or a 1v1 with him).
        for beat in attacking ? script.beats : Array(script.beats.dropLast()) {
            let before = (att: att, def: def, ball: ball)
            var arrows: [Arrow] = []
            let ballStart = ball
            var runners: [Ref] = []
            var shot: Point?
            var beaten: [Ref] = []
            var through = false
            func startPoint(_ r: Ref) -> Point { r.attacker ? before.att[r.index].p : before.def[r.index].p }

            for act in beat.acts {
                if !attacking, act.kind == "beat" || act.kind == "beatPresser" { continue }
                if act.kind == "beatPresser" {
                    let near = def.indices.filter { def[$0].group != "GK" && !outOfIt.contains(Ref(attacker: false, index: $0)) }
                    if var best = near.first {
                        for i in near.dropFirst() where gap(def[i].p, ballStart) < gap(def[best].p, ballStart) - 1e-9 { best = i }
                        beaten.append(Ref(attacker: false, index: best))
                    }
                    through = true
                    continue
                }
                guard let who = cast[act.alias] else { continue }
                var to: Point?
                switch act.target {
                case let .point(p): to = onPitch(p.x, p.y)
                case let .offset(dx, dy): to = onPitch(point(who).x + dx, point(who).y + dy)
                default: to = nil
                }
                switch act.kind {
                case "run":
                    guard let to else { continue }
                    arrows.append(Arrow(kind: .run, points: [startPoint(who), to]))
                    set(who, to)
                    runners.append(who)
                case "dribble":
                    guard let to else { continue }
                    arrows.append(Arrow(kind: .dribble, points: [startPoint(who), to]))
                    set(who, to)
                    ball = to
                    carrier = who
                case "pass":
                    guard case let .who(name) = act.target, let receiver = cast[name] else { continue }
                    arrows.append(Arrow(kind: .pass, points: [ball, point(receiver)]))
                    ball = point(receiver)
                    carrier = receiver
                case "shot":
                    guard case let .goalX(x) = act.target else { continue }
                    let target = Point(x: x, y: 1)
                    arrows.append(Arrow(kind: .pass, points: [ball, target]))
                    ball = target
                    shot = target
                case "beat":
                    guard let to else { continue }
                    set(who, to)
                    beaten.append(who)
                default:
                    continue
                }
            }

            // The other side reacts: the beaten chase from behind, the keeper sets, one presses, others track runners,
            // and the rest slide with the ball.
            for r in beaten where !outOfIt.contains(r) { outOfIt.append(r) }
            var moved = Set(beaten)
            for r in outOfIt where !beaten.contains(r) {
                let target = shot == nil ? ball : ballStart
                let p = point(r)
                set(r, onPitch(p.x + (target.x - p.x) * 0.35, min(p.y + (target.y - p.y) * 0.35, target.y - 0.03)))
                moved.insert(r)
            }
            let ballThen = shot == nil ? ball : ballStart
            if let keeper, !moved.contains(keeper) {
                let aim = shot.map(\.x) ?? 0.5 + (ballThen.x - 0.5) * 0.35
                let p = point(keeper)
                set(keeper, onPitch(p.x + (aim - p.x) * (shot == nil ? 1 : 0.8), max(p.y, 0.95)))
                moved.insert(keeper)
            }
            let field = def.indices.map { Ref(attacker: false, index: $0) }.filter { def[$0.index].group != "GK" && !moved.contains($0) }
            if shot == nil, !through, var presser = field.first {
                for r in field.dropFirst() where gap(point(r), ballThen) < gap(point(presser), ballThen) { presser = r }
                set(presser, toward(ballThen, goal, 0.045))
                moved.insert(presser)
                for runner in runners where runner != carrier {
                    let free = def.indices.map { Ref(attacker: false, index: $0) }.filter { def[$0.index].group != "GK" && !moved.contains($0) }
                    guard var marker = free.first else { break }
                    for r in free.dropFirst() where gap(point(r), point(runner)) < gap(point(marker), point(runner)) { marker = r }
                    set(marker, toward(point(runner), goal, 0.05))
                    moved.insert(marker)
                }
            }
            let dx = ballThen.x - ballStart.x, dy = ballThen.y - ballStart.y
            for i in def.indices where !moved.contains(Ref(attacker: false, index: i)) && def[i].group != "GK" {
                def[i].p = onPitch(def[i].p.x + dx * slide.x, def[i].p.y + dy * slide.y)
            }
            for i in att.indices {
                let r = Ref(attacker: true, index: i)
                guard before.att[i].p == att[i].p, r != carrier, att[i].group != "GK" else { continue }
                att[i].p = onPitch(att[i].p.x, att[i].p.y + max(dy, 0) * 0.35)
            }

            let duration = shot != nil ? 0.8 : beat.acts.contains { $0.kind == "pass" } ? 1.0 : 1.2
            let snap = (att: att, def: def, ball: ball)
            (att, def, ball) = before
            steps.append(snapshot(arrows: arrows, note: say(beat.note), duration: duration))
            (att, def, ball) = snap
        }
        if !attacking {
            let field = def.indices.filter { def[$0].group != "GK" }
            var winner = keeper
            if script.winner != "K", var best = field.first {
                for i in field.dropFirst() where gap(def[i].p, ball) < gap(def[best].p, ball) - 1e-9 { best = i }
                winner = Ref(attacker: false, index: best)
            }
            if let winner {
                // A keeper saves the shot on his line; an outfield player steps in goal-side and takes the ball onto his
                // feet, so the opponent stays in sight.
                let man = def[winner.index]
                let number = shirts[.home]?[man.number] ?? man.number
                let shotX = script.beats.last?.acts.first { $0.kind == "shot" }.flatMap { act -> Double? in
                    if case let .goalX(x) = act.target { return x }
                    return nil
                }
                let arrow: Arrow, to: Point
                if man.group == "GK", let shotX {
                    to = onPitch(shotX, man.p.y)
                    arrow = Arrow(kind: .pass, points: [ball, to])
                } else {
                    to = toward(ball, goal, 0.03)
                    arrow = Arrow(kind: .press, points: [man.p, ball])
                }
                steps.append(snapshot(arrows: [arrow], note: "\(number) \(man.group == "GK" ? "saves it" : "wins the ball")",
                                      duration: 1.0))
                def[winner.index].p = to
                ball = to
            }
        }
        steps.append(snapshot(arrows: [], note: attacking ? script.end : "Ball won", duration: 1.2))
        return steps
    }
}
