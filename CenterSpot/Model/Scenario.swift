import Foundation

/// A ready-made start for a move (D-94): a situation on the Formation sheet's Scenarios tab, built from the chosen
/// shape by `ScenarioBuilder`. `mockup/scenarios.js` is the spec; the order and words here are the mockup's.
struct Scenario: Sendable, Identifiable, Hashable {
    enum Group: String, Sendable, CaseIterable {
        case teamShape = "Team shape", smallSided = "Small-sided", setPieces = "Set pieces"
    }

    /// The team phases `ScenarioBuilder` stands a shape in.
    enum Phase: Sendable, Hashable {
        case buildUp, midfield, finalThird, counter, justWon
        case highPress, midBlock, lowBlock, caught, counterPress
    }

    /// Who carries the ball in a team shape: the keeper, or whoever stands nearest a spot.
    enum BallAt: Sendable, Hashable { case keeper, deep, leftWide, central }

    enum SetPiece: Sendable, Hashable { case corner, freeKickEdge, freeKickWide, goalKick, throwIn, penalty }

    enum Build: Sendable, Hashable {
        /// The side on the ball in `on`, the other in `off`; shifts slide a side across (positive: to its right).
        case team(on: Phase, off: Phase, ball: BallAt, onShift: Double = 0, offShift: Double = 0, press: Bool = false)
        /// `n` of the side on the ball against `m`, round `at` (in the attackers' frame). `support` places the other
        /// attackers off the carrier ("in" toward the middle); `who` and `vs` list the groups each spot takes first.
        case small(n: Int, m: Int, at: Point, support: [Point], who: [String], vs: [String], keeper: Bool = false,
                   surround: Bool = false)
        case setPiece(SetPiece)
        case kickOff
    }

    let id: String
    let group: Group
    let name: String
    let line: String
    let sizes: [Pitch.Kind]
    let build: Build

    static func == (a: Scenario, b: Scenario) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// The scenarios a size offers, in the sheet's order: those listed for it whose counts fit a team that size.
    static func available(for kind: Pitch.Kind) -> [Scenario] {
        let outfield = kind.players - 1
        return all.filter { scenario in
            guard scenario.sizes.contains(kind) else { return false }
            if case let .small(n, m, _, _, _, _, _, _) = scenario.build { return n <= outfield && m <= outfield }
            return true
        }
    }

    private static let every: [Pitch.Kind] = [.full, .sevenASide, .fiveASide]
    private static func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }

    static let all: [Scenario] = [
        // Team shape
        Scenario(id: "build-up", group: .teamShape, name: "Build-up v press",
                 line: "Keeper on the ball, centre-backs split, their front line presses", sizes: every,
                 build: .team(on: .buildUp, off: .highPress, ball: .keeper)),
        Scenario(id: "midfield", group: .teamShape, name: "Through midfield", line: "On the ball in the middle third, against a mid block",
                 sizes: every, build: .team(on: .midfield, off: .midBlock, ball: .deep)),
        Scenario(id: "final-third", group: .teamShape, name: "Final third v low block",
                 line: "Full-backs high, everyone in their half, they sit deep", sizes: every,
                 build: .team(on: .finalThird, off: .lowBlock, ball: .leftWide)),
        Scenario(id: "switch", group: .teamShape, name: "Switch of play", line: "Overloaded on the left, the far winger free",
                 sizes: [.full, .sevenASide], build: .team(on: .finalThird, off: .midBlock, ball: .leftWide, onShift: -0.08, offShift: 0.1)),
        Scenario(id: "counter", group: .teamShape, name: "Counter-attack", line: "Ball just won deep, their team caught upfield",
                 sizes: every, build: .team(on: .counter, off: .caught, ball: .central)),
        Scenario(id: "counter-press", group: .teamShape, name: "Counter-press", line: "Ball just won high: break before their swarm closes",
                 sizes: every, build: .team(on: .justWon, off: .counterPress, ball: .deep, press: true)),

        // Small-sided
        Scenario(id: "1v1-wing", group: .smallSided, name: "1v1 on the wing", line: "Winger runs at the full-back", sizes: every,
                 build: .small(n: 1, m: 1, at: p(0.12, 0.74), support: [], who: ["W,WM"], vs: ["FB"], keeper: true)),
        Scenario(id: "1v1-keeper", group: .smallSided, name: "1v1 with the keeper", line: "Through on goal, only the keeper to beat",
                 sizes: every, build: .small(n: 1, m: 0, at: p(0.5, 0.8), support: [], who: ["ST,W,AM"], vs: [], keeper: true)),
        Scenario(id: "2v1-overlap", group: .smallSided, name: "2v1 overlap", line: "Full-back runs round the winger", sizes: every,
                 build: .small(n: 2, m: 1, at: p(0.16, 0.64), support: [p(-0.06, -0.08)], who: ["W,WM", "FB"], vs: ["FB"], keeper: true)),
        Scenario(id: "2v1-one-two", group: .smallSided, name: "2v1 one-two", line: "Give and go past one defender", sizes: every,
                 build: .small(n: 2, m: 1, at: p(0.42, 0.66), support: [p(0.16, 0.06)], who: ["AM,CM", "ST"], vs: ["CB"], keeper: true)),
        Scenario(id: "2v2-box", group: .smallSided, name: "2v2 in the box", line: "Two attackers, two defenders, the keeper", sizes: every,
                 build: .small(n: 2, m: 2, at: p(0.34, 0.8), support: [p(0.22, 0.06)], who: ["ST", "W,AM"], vs: ["CB", "CB,FB"],
                               keeper: true)),
        Scenario(id: "3v1-rondo", group: .smallSided, name: "3v1 keep the ball", line: "A triangle round one presser", sizes: every,
                 build: .small(n: 3, m: 1, at: p(0.5, 0.48), support: [p(0.14, 0.1), p(-0.14, 0.1)],
                               who: ["CM,DM", "CM,AM", "CM,DM,AM"], vs: ["ST,AM"])),
        Scenario(id: "3v2-counter", group: .smallSided, name: "3v2 counter", line: "Three break on two, the keeper back", sizes: every,
                 build: .small(n: 3, m: 2, at: p(0.5, 0.6), support: [p(0.24, -0.02), p(-0.24, -0.02)],
                               who: ["AM,CM,ST", "W,ST", "W,ST"], vs: ["CB", "CB"], keeper: true)),
        Scenario(id: "3v3-midfield", group: .smallSided, name: "3v3 in midfield", line: "Even numbers in the middle third",
                 sizes: [.full, .sevenASide],
                 build: .small(n: 3, m: 3, at: p(0.5, 0.48), support: [p(0.2, 0.08), p(-0.2, 0.08)],
                               who: ["DM,CM", "CM,AM", "CM,AM"], vs: ["CM,DM", "CM,AM", "CM,AM"], keeper: true)),
        Scenario(id: "3v4-build-up", group: .smallSided, name: "3v4 outnumbered", line: "Playing out with one fewer",
                 sizes: [.full, .sevenASide],
                 build: .small(n: 3, m: 4, at: p(0.5, 0.2), support: [p(0.26, 0.04), p(-0.26, 0.04)],
                               who: ["DM,CB", "CB", "CB,FB"], vs: ["ST", "ST,AM", "W,WM", "W,WM,CM"], keeper: true)),
        Scenario(id: "4v3-overload", group: .smallSided, name: "4v3 flank overload", line: "One more on the left side",
                 sizes: [.full, .sevenASide],
                 build: .small(n: 4, m: 3, at: p(0.2, 0.62), support: [p(-0.08, -0.1), p(0.16, 0.04), p(0.12, 0.16)],
                               who: ["W,WM", "FB", "CM,AM", "ST,AM"], vs: ["FB", "CB", "WM,CM"], keeper: true)),
        Scenario(id: "1v3-surrounded", group: .smallSided, name: "1v3 surrounded", line: "One on the ball, three closing in",
                 sizes: [.full, .sevenASide],
                 build: .small(n: 1, m: 3, at: p(0.5, 0.56), support: [], who: ["CM,AM"], vs: ["CM,DM", "CM", "AM,ST,W"], keeper: true,
                               surround: true)),

        // Set pieces
        Scenario(id: "corner", group: .setPieces, name: "Corner", line: "Near post, far post, edge of the box", sizes: [.full],
                 build: .setPiece(.corner)),
        Scenario(id: "free-kick-edge", group: .setPieces, name: "Free kick, edge of the box", line: "A wall of four, runners ready",
                 sizes: [.full], build: .setPiece(.freeKickEdge)),
        Scenario(id: "free-kick-wide", group: .setPieces, name: "Free kick, wide", line: "Whipped in from the right", sizes: [.full],
                 build: .setPiece(.freeKickWide)),
        Scenario(id: "goal-kick", group: .setPieces, name: "Goal kick", line: "Keeper to a centre-back in the box", sizes: [.full],
                 build: .setPiece(.goalKick)),
        Scenario(id: "throw-in", group: .setPieces, name: "Throw-in", line: "Down the left, in their half", sizes: [.full],
                 build: .setPiece(.throwIn)),
        Scenario(id: "penalty", group: .setPieces, name: "Penalty", line: "Everyone outside the box", sizes: [.full],
                 build: .setPiece(.penalty)),
        Scenario(id: "kick-off", group: .setPieces, name: "Kick-off", line: "Both teams in their own half", sizes: every,
                 build: .kickOff),
    ]
}

/// The board a scenario sets up: our players and theirs (shirt number, role, place) and the ball, attacking upward.
struct ScenarioBoard: Sendable, Equatable {
    struct Player: Sendable, Equatable {
        let number: Int
        let roleID: String
        let point: Point
    }

    let home: [Player]
    let away: [Player]
    let ball: Point
}

extension Pitch.Kind {
    /// Players a side, keeper included.
    var players: Int {
        switch self {
        case .full: 11
        case .sevenASide: 7
        case .fiveASide: 5
        }
    }

    /// The opponent's shape in scenarios (D-94): the size's most common one.
    var scenarioOpponent: String {
        switch self {
        case .full: "4-4-2"
        case .sevenASide: "7-2-3-1"
        case .fiveASide: "5-2-2"
        }
    }
}
