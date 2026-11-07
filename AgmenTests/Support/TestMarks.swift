import Foundation
import Testing
@testable import Agmen

/// Marks (D-65) on the hand-built tactics, without indexing steps by hand.
extension TestTactics {
    /// `small()` with `marks` on step `index` (0-based).
    static func small(marks: Marks, onStep index: Int = 0) -> Tactic {
        changing(small(), step: index) { $0.marks = marks }
    }

    /// `tactic` with step `index` of the first phase changed; an index out of range changes nothing.
    static func changing(_ tactic: Tactic, step index: Int, _ change: (inout Step) -> Void) -> Tactic {
        var tactic = tactic
        guard var phase = tactic.phases.first, phase.steps.indices.contains(index) else { return tactic }
        var step = phase.steps.remove(at: index)
        change(&step)
        phase.steps.insert(step, at: index)
        tactic.phases = [phase] + tactic.phases.dropFirst()
        return tactic
    }

    /// Step `index` of the first phase, failing the test if there is none.
    static func step(_ index: Int, of tactic: Tactic, sourceLocation: SourceLocation = #_sourceLocation) throws -> Step {
        try #require(tactic.phases.first?.steps[safe: index], sourceLocation: sourceLocation)
    }

    static func marks(_ index: Int, of tactic: Tactic, sourceLocation: SourceLocation = #_sourceLocation) throws -> Marks {
        try step(index, of: tactic, sourceLocation: sourceLocation).marks
    }

    /// One of each kind on the small tactic: a zone, a home line (4 and 9), rings on 9 and heat.
    static let someMarks = Marks(
        zones: [Zone(id: "z1", x: 0.1, y: 0.5, w: 0.3, h: 0.2, colour: .sky)],
        lines: [ShapeLine(id: "l1", tokens: ["h4", "h9"])],
        glows: [Glow(id: "g1", target: .token("h9")), Glow(id: "g2", target: .spot(Point(x: 0.5, y: 0.87), radius: 0.12))]
    )
}
