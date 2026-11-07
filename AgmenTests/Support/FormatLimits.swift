import Foundation
@testable import Agmen

/// Every limit in docs/FORMAT.md's Rules table, checked on a tactic that `TacticFormat.decode` let through. Returns
/// what broke, in words, so a fuzz failure says which rule a repaired file still breaks.
enum FormatLimits {
    static func violations(of tactic: Tactic, knownRoleIDs: Set<String>? = TacticFormat.bundledRoleIDs) -> [String] {
        var broken: [String] = []
        func check(_ ok: Bool, _ rule: @autoclosure () -> String) {
            if !ok { broken.append(rule()) }
        }

        check(tactic.sides.map(\.id) == [.home, .away], "sides are home then away")
        check(tactic.tokens.count <= TacticFormat.maxTokens, "≤ 30 tokens (\(tactic.tokens.count))")
        let tokenIDs = tactic.tokens.map(\.id)
        check(Set(tokenIDs).count == tokenIDs.count, "unique token ids")
        for token in tactic.tokens {
            check(token.kind != .player || token.side != nil, "player \(token.id) has a side")
            check(token.number.map(Token.numberRange.contains) ?? true, "number 0…99 (\(token.number ?? 0))")
            check((token.name?.count ?? 0) <= Token.maxNameLength, "name ≤ 24 characters")
            if let roleID = token.roleID, let knownRoleIDs {
                check(knownRoleIDs.contains(roleID), "known roleID \(roleID)")
            }
        }

        check(Phase.countRange.contains(tactic.phases.count), "1…2 phases")
        check(Set(tactic.phases.map(\.id)).count == tactic.phases.count, "unique phase ids")
        for phase in tactic.phases {
            broken += stepViolations(phase.steps, tokenIDs: Set(tokenIDs))
            for step in phase.steps { broken += markViolations(step.marks, tokens: tactic.tokens) }
        }
        return broken
    }

    /// D-65's marks: ≤ 12, unique ids, zones inside the pitch and big enough, lines of 2…11 players of one side each
    /// once, rings on players, heat on the pitch with a radius in range.
    private static func markViolations(_ marks: Marks, tokens: [Token]) -> [String] {
        var broken: [String] = []
        func check(_ ok: Bool, _ rule: @autoclosure () -> String) {
            if !ok { broken.append(rule()) }
        }
        let tolerance = Zone.tolerance
        let sides = Dictionary(tokens.filter { $0.kind == .player }.map { ($0.id, $0.side) }, uniquingKeysWith: { a, _ in a })
        check(marks.count <= Marks.maxCount, "≤ 12 marks (\(marks.count))")
        check(Set(marks.ids).count == marks.ids.count, "unique mark ids")
        for zone in marks.zones {
            check(zone.x >= 0 && zone.y >= 0, "zone \(zone.id) starts on the pitch")
            check(zone.x + zone.w <= 1 + tolerance && zone.y + zone.h <= 1 + tolerance, "zone \(zone.id) ends on the pitch")
            check(zone.w >= Zone.minSize - tolerance && zone.h >= Zone.minSize - tolerance, "zone \(zone.id) ≥ 0.04 each side")
        }
        for line in marks.lines {
            check((ShapeLine.minTokens...ShapeLine.maxTokens).contains(line.tokens.count), "line \(line.id) joins 2…11")
            check(Set(line.tokens).count == line.tokens.count, "line \(line.id) names each player once")
            check(line.tokens.allSatisfy { sides[$0] != nil }, "line \(line.id) joins players")
            check(Set(line.tokens.map { sides[$0] ?? nil }).count == 1, "line \(line.id) is one side")
        }
        for glow in marks.glows {
            switch glow.target {
            case .token(let id):
                check(sides[id] != nil, "glow \(glow.id) is on a player")
            case .spot(let centre, let radius):
                check((0...1).contains(centre.x) && (0...1).contains(centre.y), "heat \(glow.id) on the pitch")
                check(Glow.radiusRange.contains(radius), "heat \(glow.id) radius 0.03…0.25")
            }
        }
        return broken
    }

    private static func stepViolations(_ steps: [Step], tokenIDs: Set<String>) -> [String] {
        var broken: [String] = []
        func check(_ ok: Bool, _ rule: @autoclosure () -> String) {
            if !ok { broken.append(rule()) }
        }
        func onPitch(_ points: [Point]) -> Bool {
            points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) }
        }

        check(Phase.stepCountRange.contains(steps.count), "1…40 steps (\(steps.count))")
        check(Set(steps.map(\.id)).count == steps.count, "unique step ids")
        for (index, step) in steps.enumerated() {
            check(Step.durationRange.contains(step.duration), "duration 0.3…5 (\(step.duration))")
            check((step.note?.count ?? 0) <= Step.maxNoteLength, "note ≤ 140 characters")
            check(Set(step.positions.keys) == tokenIDs, "step \(step.id) places every token and nothing else")
            check(onPitch(Array(step.positions.values)), "positions in 0…1")
            check(step.arrows.count <= Step.maxArrows, "≤ 30 arrows")
            for arrow in step.arrows {
                check(Path.pointCountRange.contains(arrow.points.count), "arrow has 2…200 points")
                check(onPitch(arrow.points), "arrow points in 0…1")
            }
            let next = steps.indices.contains(index + 1) ? steps[index + 1] : nil
            check(next != nil || step.runs.isEmpty, "no runs on the last step")
            for (id, run) in step.runs {
                check(tokenIDs.contains(id), "run for a known token")
                check(Path.pointCountRange.contains(run.points.count), "run has 2…200 points")
                check(onPitch(run.points), "run points in 0…1")
                check(run.points.first == step.positions[id], "run \(id) starts at its position")
                check(run.points.last == next?.positions[id], "run \(id) ends at its next position")
            }
        }
        return broken
    }
}

/// Runs `work` on another thread and gives up after `seconds`, so a hang fails one case instead of the whole run.
/// A hung call can't be stopped; its thread is left blocked and the case is reported.
enum Deadline {
    static func run<T: Sendable>(seconds: Double, _ work: @escaping @Sendable () -> T) -> T? {
        let box = Box<T>()
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            box.set(work())
            done.signal()
        }
        guard done.wait(timeout: .now() + seconds) == .success else { return nil }
        return box.get()
    }

    private final class Box<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var value: T?
        func set(_ newValue: T) { lock.withLock { value = newValue } }
        func get() -> T? { lock.withLock { value } }
    }
}

/// `TacticLibrary` holds a `UserDefaults`, which is thread-safe but not marked `Sendable`; this lets a test hand a
/// library to `Deadline`.
struct SharedLibrary: @unchecked Sendable {
    let library: TacticLibrary
}
