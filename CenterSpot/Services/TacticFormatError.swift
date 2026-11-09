import Foundation

/// Why a `.tactic` file or link was refused (D-27). Only two messages ever reach the user.
enum TacticFormatError: Error, Sendable, Equatable {
    /// `schemaVersion` is higher than this build understands.
    case newerVersion
    /// Anything else: too big, not JSON, wrong shape, over a limit, a NaN.
    case unreadable

    var message: String {
        switch self {
        case .newerVersion: "Made with a newer version of CenterSpot."
        case .unreadable: "This file isn't a tactic we can open."
        }
    }
}

extension TacticFormatError: LocalizedError {
    var errorDescription: String? { message }
}
