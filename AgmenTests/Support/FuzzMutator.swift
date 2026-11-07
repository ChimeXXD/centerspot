import Foundation

/// Deterministic hostile versions of a `.tactic` file for `FuzzImportTests`: byte damage on the raw text and
/// structural damage on its JSON tree. Every case is named so a failure can be rebuilt from the seed.
struct FuzzMutator {
    struct Case: Sendable {
        let name: String
        let data: Data
    }

    private var rng: SeededGenerator
    let tree: FuzzJSON
    let bytes: Data
    private let paths: [[FuzzJSON.Step]]

    /// - Parameter focus: only damage nodes under an object member with this key (e.g. "marks"); nil damages anywhere.
    init(fixture: Data, seed: UInt64, focus: String? = nil) throws {
        rng = SeededGenerator(seed: seed)
        let parsed = try FuzzJSON(data: fixture)
        tree = parsed
        bytes = fixture
        paths = focus.map { parsed.paths(under: $0) } ?? parsed.paths
    }

    /// Values that are the wrong type almost everywhere.
    static let wrongTypes: [FuzzJSON] = [
        .null, .bool(true), .number("0"), .number("-1"), .string(""), .string("x"),
        .array([]), .array([.number("1")]), .object([]), .object([.init(key: "x", value: .number("1"))]),
    ]

    /// Numbers at every edge: huge, tiny, negative zero, past Double and Int, and literals JSON doesn't allow.
    static let hostileNumbers = [
        "1e308", "-1e308", "1e309", "-1e309", "-0", "-0.0", "0", "1", "-1", "0.5", "7.5", "1e20", "-1e20", "1e-400",
        "5e-324", "2147483648", "-2147483649", "9223372036854775807", "9223372036854775808", "-9223372036854775809",
        "99999999999999999999999999999999", "0.30000000000000004", "1E2", "1.0", "NaN", "Infinity", "-Infinity", "nan",
        "01", "+1", ".5", "1.", "0x10", "1e", "--1",
    ]

    // MARK: Byte damage

    mutating func byteCase(_ n: Int) -> Case {
        var data = bytes
        let kind = Int.random(in: 0..<6, using: &rng)
        let at = Int.random(in: 0..<max(data.count, 1), using: &rng)
        switch kind {
        case 0:
            let flips = Int.random(in: 1...8, using: &rng)
            for _ in 0..<flips {
                let i = Int.random(in: 0..<data.count, using: &rng)
                data[data.startIndex + i] ^= UInt8(1) << UInt8.random(in: 0..<8, using: &rng)
            }
            return Case(name: "byte#\(n) flip×\(flips)", data: data)
        case 1:
            return Case(name: "byte#\(n) truncate@\(at)", data: data.prefix(at))
        case 2:
            let junk: [UInt8] = [0xFF, 0xC0, 0xAF, 0x00, 0xED, 0xA0, 0x80, 0xF8, 0xFE, 0x22, 0x5C, 0x7B, 0x5D]
            let count = Int.random(in: 1...6, using: &rng)
            let insert = (0..<count).map { _ in junk.randomElement(using: &rng) ?? 0 }
            data.insert(contentsOf: insert, at: data.startIndex + at)
            return Case(name: "byte#\(n) insert\(insert)@\(at)", data: data)
        case 3:
            let length = min(Int.random(in: 1...64, using: &rng), data.count - at)
            data.removeSubrange(data.startIndex + at ..< data.startIndex + at + length)
            return Case(name: "byte#\(n) delete\(length)@\(at)", data: data)
        case 4:
            let length = min(Int.random(in: 1...256, using: &rng), data.count - at)
            let range = data.startIndex + at ..< data.startIndex + at + length
            data.insert(contentsOf: data[range], at: range.upperBound)
            return Case(name: "byte#\(n) duplicate\(length)@\(at)", data: data)
        default:
            let token = ["\"", "{", "}", "[", "]", ",", ":", "\\u0000", "\\ud800", "null", "-0", "1e999"]
                .randomElement(using: &rng) ?? ""
            data.insert(contentsOf: Data(token.utf8), at: data.startIndex + at)
            return Case(name: "byte#\(n) splice \(token)@\(at)", data: data)
        }
    }

    // MARK: Structural damage

    mutating func treeCase(_ n: Int) -> Case {
        let path = paths.randomElement(using: &rng) ?? []
        let field = tree.key(at: path) ?? "·"
        let kind = Int.random(in: 0..<10, using: &rng)
        var label = ""
        var changed: FuzzJSON
        switch kind {
        case 0, 1, 2:
            (label, changed) = objectChange(at: path, kind: kind)
        case 3:
            let value = Self.wrongTypes.randomElement(using: &rng) ?? .null
            (label, changed) = ("wrong type \(value.text)", tree.replacing(at: path) { _ in value })
        case 4:
            let literal = Self.hostileNumbers.randomElement(using: &rng) ?? "0"
            (label, changed) = ("number \(literal)", tree.replacing(at: path) { _ in .number(literal) })
        case 5:
            label = "number as string"
            changed = tree.replacing(at: path) { node in
                if case .number(let literal) = node { return .string(literal) }
                return node
            }
        case 6:
            let length = [25, 141, 1_000, 100_000, 300_000].randomElement(using: &rng) ?? 25
            let unit = ["a", "é", "👩🏽‍⚽", "\u{0301}", "\u{0}", "/", "\n"].randomElement(using: &rng) ?? "a"
            label = "string \(unit.unicodeScalars.map { String($0.value, radix: 16) })×\(length)"
            changed = tree.replacing(at: path) { _ in .string(String(repeating: unit, count: length)) }
        case 7:
            (label, changed) = arrayChange(at: path)
        case 8:
            let depth = [2, 64, 513, 10_000].randomElement(using: &rng) ?? 2
            let asObject = Bool.random(using: &rng)
            // Built as text: a 10,000-deep tree would overflow the test thread's stack while writing or freeing it.
            let inner = tree.node(at: path)?.text ?? "null"
            let nested = String(repeating: asObject ? "{\"a\":" : "[", count: depth) + inner
                + String(repeating: asObject ? "}" : "]", count: depth)
            let marker = "__nest\(n)__"
            let text = tree.replacing(at: path) { _ in .number(marker) }.text
            let label = "nest \(asObject ? "{}" : "[]")×\(depth)"
            return Case(name: "tree#\(n) \(field): \(label)", data: Data(text.replacingOccurrences(of: marker, with: nested).utf8))
        default:
            label = "empty container"
            changed = tree.replacing(at: path) { node in
                switch node {
                case .array: .array([])
                case .object: .object([])
                default: .null
                }
            }
        }
        return Case(name: "tree#\(n) \(field): \(label)", data: changed.data)
    }

    /// Delete, duplicate or reorder the members of the object at `path` (or its parent).
    private mutating func objectChange(at path: [FuzzJSON.Step], kind: Int) -> (String, FuzzJSON) {
        var target = path
        while let node = tree.node(at: target), !node.isObject, !target.isEmpty { target.removeLast() }
        guard case .object(let members)? = tree.node(at: target), !members.isEmpty else { return ("no object", tree) }
        let i = Int.random(in: 0..<members.count, using: &rng)
        var copy = members
        switch kind {
        case 0:
            copy.remove(at: i)
            return ("delete key \(members[i].key)", tree.replacing(at: target) { _ in .object(copy) })
        case 1:
            var twin = members[i]
            if Bool.random(using: &rng) { twin.value = Self.wrongTypes.randomElement(using: &rng) ?? .null }
            copy.insert(twin, at: Int.random(in: 0...copy.count, using: &rng))
            return ("duplicate key \(twin.key)=\(twin.value.text.prefix(20))", tree.replacing(at: target) { _ in .object(copy) })
        default:
            copy.shuffle(using: &rng)
            return ("reorder keys", tree.replacing(at: target) { _ in .object(copy) })
        }
    }

    /// Drop, duplicate or multiply an element of the array at `path` (or its parent): 31 tokens, 41 steps, 201 points.
    private mutating func arrayChange(at path: [FuzzJSON.Step]) -> (String, FuzzJSON) {
        var target = path
        while let node = tree.node(at: target), !node.isArray, !target.isEmpty { target.removeLast() }
        guard case .array(let items)? = tree.node(at: target), !items.isEmpty else { return ("no array", tree) }
        let i = Int.random(in: 0..<items.count, using: &rng)
        var copy = items
        let action = Int.random(in: 0..<3, using: &rng)
        switch action {
        case 0:
            copy.remove(at: i)
            return ("drop element \(i)", tree.replacing(at: target) { _ in .array(copy) })
        case 1:
            copy.insert(items[i], at: i)
            return ("duplicate element \(i)", tree.replacing(at: target) { _ in .array(copy) })
        default:
            let total = [31, 41, 201, 1_000].randomElement(using: &rng) ?? 31
            while copy.count < total { copy.append(items[i]) }
            return ("grow to \(total)", tree.replacing(at: target) { _ in .array(copy) })
        }
    }
}

private extension FuzzJSON {
    var isObject: Bool {
        if case .object = self { return true }
        return false
    }

    var isArray: Bool {
        if case .array = self { return true }
        return false
    }
}
