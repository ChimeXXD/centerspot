#if DEBUG
import Foundation

/// D5-1: how long does a real export take on this device, and how big is it? Launch with `-exportBench`; it exports
/// the hero move (5 steps) and a 10-step move in every video format with `VideoExporter` and prints one
/// `AGMEN-EXPORT …` line each, then deletes the files. Replaces the Day 2 spike (D2-6).
enum ExportBench {
    static func report(hero: Tactic) async {
        for (name, tactic) in [("hero", hero), ("ten-steps", tenStepMove(from: hero))] {
            for format in VideoFormat.allCases {
                do {
                    let result = try await VideoExporter.export(tactic, settings: VideoExportSettings(format: format))
                    print("\(result.logLine) move=\(name) steps=\(tactic.phases.first?.steps.count ?? 0)")
                    VideoExporter.discard(result.url)
                } catch {
                    print("AGMEN-EXPORT failed move=\(name) format=\(format.rawValue): \(error)")
                }
            }
        }
        print("AGMEN-EXPORT done")
    }

    /// The hero's five steps, then back through 4, 3, 2, 1 and on to 2 again: ten steps of real movement. The copies
    /// drop their drawn runs (a run belongs to the move it was drawn for) and keep arrows and notes.
    static func tenStepMove(from hero: Tactic) -> Tactic {
        var tactic = hero
        guard let steps = hero.phases.first?.steps, steps.count == 5 else { return hero }
        let order = [0, 1, 2, 3, 4, 3, 2, 1, 0, 1]
        tactic.phases[0].steps = order.enumerated().map { i, source in
            var step = steps[source]
            step.id = "s\(i + 1)"
            if i >= steps.count { step.runs = [:] }
            return step
        }
        // The last original step's runs led nowhere; now step 5 moves on to step 6.
        tactic.phases[0].steps[4].runs = [:]
        return tactic
    }
}
#endif
