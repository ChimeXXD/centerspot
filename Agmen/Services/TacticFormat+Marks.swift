import Foundation

/// docs/FORMAT.md's rules for a step's marks (D-65), as refuse and repair (D-27). Per-value rules that decoding already
/// enforces: numbers are finite, zones are inside the pitch and big enough (`Zone`), heat spots and radii are clamped
/// (`Glow`), an unknown zone colour is lime.
extension TacticFormat {
    /// Structure and safety: at most 12 marks on the step and 11 players named by any line. Checked before repairs, so a
    /// file over a limit is refused even if a repair would then drop the extra.
    static func marksWithinLimits(_ marks: Marks) -> Bool {
        marks.count <= Marks.maxCount && marks.lines.allSatisfy { $0.tokens.count <= ShapeLine.maxTokens }
    }

    /// The marks with every cosmetic problem repaired: a line keeps the players of its first player's side, each once,
    /// and is dropped with fewer than two; rings on anything but a player are dropped; a repeated id drops the later
    /// mark. Edits that remove a player or change a side call it too, so a saved file always reopens unchanged.
    static func repairedMarks(_ marks: Marks, tokens: [Token]) -> Marks {
        var sides: [String: Side.ID] = [:]
        for token in tokens where token.kind == .player {
            if let side = token.side { sides[token.id] = side }
        }

        var lines: [ShapeLine] = []
        for line in marks.lines {
            guard let first = line.tokens.first(where: { sides[$0] != nil }), let side = sides[first] else { continue }
            var kept: [String] = []
            for id in line.tokens where sides[id] == side && !kept.contains(id) { kept.append(id) }
            guard kept.count >= ShapeLine.minTokens else { continue }
            lines.append(ShapeLine(id: line.id, tokens: kept))
        }
        let glows = marks.glows.filter { glow in glow.tokenID.map { sides[$0] != nil } ?? true }

        var seen = Set<String>()
        func fresh(_ id: String) -> Bool { seen.insert(id).inserted }
        let zones = marks.zones.filter { fresh($0.id) }
        return Marks(zones: zones, lines: lines.filter { fresh($0.id) }, glows: glows.filter { fresh($0.id) })
    }
}
