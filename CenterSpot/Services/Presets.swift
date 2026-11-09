import Foundation

/// The formation and role presets bundled from `presets/` (D-14).
struct Presets: Sendable {
    let formations: [Formation]
    let roles: [Role]

    enum LoadError: Error { case missing(String) }

    static func bundled(in bundle: Bundle = .main) throws -> Presets {
        struct FormationFile: Decodable { let formations: [Formation] }
        struct RoleFile: Decodable { let roles: [Role] }
        func load<T: Decodable>(_ name: String, as: T.Type) throws -> T {
            guard let url = bundle.url(forResource: name, withExtension: "json") else { throw LoadError.missing(name) }
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        }
        return Presets(formations: try load("formations", as: FormationFile.self).formations,
                       roles: try load("roles", as: RoleFile.self).roles)
    }

    /// The bundled presets, loaded once; empty if the bundle lacks them (`PresetTests` checks they load).
    static let shared: Presets = (try? bundled()) ?? Presets(formations: [], roles: [])

    func formation(_ id: String) -> Formation? { formations.first { $0.id == id } }

    func role(_ id: String?) -> Role? { id.flatMap { id in roles.first { $0.id == id } } }
}
