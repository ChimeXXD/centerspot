import Foundation

/// SplitMix64 with a fixed seed, so every run of `FuzzImportTests` builds exactly the same cases.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A JSON tree the fuzzer can bend in ways `JSONSerialization` can't write: duplicate keys, keys in any order, and
/// numbers kept as raw literals ("-0", "1e308", "NaN").
indirect enum FuzzJSON: Sendable, Equatable {
    struct Member: Sendable, Equatable {
        var key: String
        var value: FuzzJSON
    }

    case null
    case bool(Bool)
    case number(String)
    case string(String)
    case array([FuzzJSON])
    case object([Member])

    /// Reads real JSON. Object keys are sorted so the tree, and every case built from it, is the same on every run.
    init(data: Data) throws {
        self.init(any: try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]))
    }

    private init(any: Any) {
        switch any {
        case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID():
            self = .bool(number.boolValue)
        case let number as NSNumber:
            self = .number(number.stringValue)
        case let string as String:
            self = .string(string)
        case let array as [Any]:
            self = .array(array.map(FuzzJSON.init(any:)))
        case let object as [String: Any]:
            self = .object(object.keys.sorted().map { Member(key: $0, value: FuzzJSON(any: object[$0] as Any)) })
        default:
            self = .null
        }
    }

    // MARK: Writing

    var text: String {
        var out = ""
        write(into: &out)
        return out
    }

    var data: Data { Data(text.utf8) }

    private func write(into out: inout String) {
        switch self {
        case .null: out += "null"
        case .bool(let value): out += value ? "true" : "false"
        case .number(let literal): out += literal
        case .string(let value): Self.writeString(value, into: &out)
        case .array(let items):
            out += "["
            for (index, item) in items.enumerated() {
                if index > 0 { out += "," }
                item.write(into: &out)
            }
            out += "]"
        case .object(let members):
            out += "{"
            for (index, member) in members.enumerated() {
                if index > 0 { out += "," }
                Self.writeString(member.key, into: &out)
                out += ":"
                member.value.write(into: &out)
            }
            out += "}"
        }
    }

    private static func writeString(_ value: String, into out: inout String) {
        out += "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case _ where scalar.value < 0x20: out += String(format: "\\u%04x", scalar.value)
            default: out.unicodeScalars.append(scalar)
            }
        }
        out += "\""
    }

    // MARK: Paths

    /// One step down the tree: an array index or an object member index (not its key, so duplicates stay apart).
    enum Step: Sendable, Equatable {
        case index(Int)
        case member(Int)
    }

    /// Every node's path, root first, in a stable order.
    var paths: [[Step]] {
        var result: [[Step]] = [[]]
        switch self {
        case .array(let items):
            for (i, item) in items.enumerated() { result += item.paths.map { [.index(i)] + $0 } }
        case .object(let members):
            for (i, member) in members.enumerated() { result += member.value.paths.map { [.member(i)] + $0 } }
        default:
            break
        }
        return result
    }

    /// The object key that leads to the node at `path`, if its last step is a member ("x", "number", "title").
    func key(at path: [Step]) -> String? {
        guard let last = path.last, case .member(let i) = last,
              case .object(let members)? = node(at: Array(path.dropLast())), members.indices.contains(i)
        else { return nil }
        return members[i].key
    }

    func node(at path: [Step]) -> FuzzJSON? {
        guard let first = path.first else { return self }
        switch (self, first) {
        case (.array(let items), .index(let i)) where items.indices.contains(i):
            return items[i].node(at: Array(path.dropFirst()))
        case (.object(let members), .member(let i)) where members.indices.contains(i):
            return members[i].value.node(at: Array(path.dropFirst()))
        default:
            return nil
        }
    }

    /// The tree with the node at `path` passed through `change`. A path that no longer exists leaves it as it was.
    func replacing(at path: [Step], _ change: (FuzzJSON) -> FuzzJSON) -> FuzzJSON {
        guard let first = path.first else { return change(self) }
        let rest = Array(path.dropFirst())
        switch (self, first) {
        case (.array(var items), .index(let i)) where items.indices.contains(i):
            items[i] = items[i].replacing(at: rest, change)
            return .array(items)
        case (.object(var members), .member(let i)) where members.indices.contains(i):
            members[i].value = members[i].value.replacing(at: rest, change)
            return .object(members)
        default:
            return self
        }
    }
}
