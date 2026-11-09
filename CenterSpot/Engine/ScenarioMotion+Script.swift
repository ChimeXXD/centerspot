import Foundation

/// The scripts behind every scenario move (D-96), read from `presets/scenario-moves.json`, which
/// `mockup/gen_scenario_fixtures.js` writes from `mockup/scenario-motion.js`.
extension ScenarioMotion {
    struct Script: Decodable, Sendable {
        enum Cast: Sendable {
            case ball
            case role(groups: [String], side: String, fallback: Point)
        }

        struct Beat: Decodable, Sendable {
            let note: String
            let acts: [Act]
        }

        enum Target: Sendable {
            case point(Point)
            case offset(dx: Double, dy: Double)
            case who(String)
            case goalX(Double)
            case none
        }

        struct Act: Decodable, Sendable {
            let kind: String
            let alias: String
            let target: Target

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                kind = try c.decode(String.self)
                alias = c.isAtEnd ? "" : try c.decode(String.self)
                if c.isAtEnd {
                    target = .none
                } else if let xy = try? c.decode([Double].self) {
                    target = .point(Point(x: xy[0], y: xy[1]))
                } else if let offset = try? c.decode([String: Double].self) {
                    target = .offset(dx: offset["dx"] ?? 0, dy: offset["dy"] ?? 0)
                } else if let who = try? c.decode(String.self) {
                    target = .who(who)
                } else {
                    target = .goalX(try c.decode(Double.self))
                }
            }
        }

        let cast: [(alias: String, entry: Cast)]
        let beats: [Beat]
        let end: String
        /// Who wins the ball on Defending when it isn't the nearest outfield player: "K", the keeper (a penalty).
        let winner: String?

        private enum Keys: String, CodingKey { case cast, beats, end, winner }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            var list = try c.nestedUnkeyedContainer(forKey: .cast)
            var cast: [(String, Cast)] = []
            while !list.isAtEnd {
                var entry = try list.nestedUnkeyedContainer()
                let alias = try entry.decode(String.self)
                let groups = try entry.decode(String.self)
                if groups == "@ball" {
                    cast.append((alias, .ball))
                } else {
                    let side = try entry.decode(String.self)
                    let xy = try entry.decode([Double].self)
                    cast.append((alias, .role(groups: groups.split(separator: ",").map(String.init), side: side,
                                              fallback: Point(x: xy[0], y: xy[1]))))
                }
            }
            self.cast = cast
            beats = try c.decode([Beat].self, forKey: .beats)
            end = try c.decode(String.self, forKey: .end)
            winner = try c.decodeIfPresent(String.self, forKey: .winner)
        }
    }

    /// The bundled scripts by scenario id; empty if the bundle lacks them (`ScenarioMoveTests` checks every scenario has one).
    static let scripts: [String: Script] = {
        struct File: Decodable { let scripts: [String: Script] }
        guard let url = Bundle.main.url(forResource: "scenario-moves", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [:] }
        return file.scripts
    }()
}
