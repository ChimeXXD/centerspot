import Foundation

/// How playback and export look at the pitch (D-66, D-76): flat from above, or the tilted broadcast camera that
/// follows the ball. One choice for the whole app, remembered; Broadcast until someone picks Flat.
enum BoardCamera: String, Sendable, CaseIterable {
    case flat, broadcast

    /// The `UserDefaults` key both Play and Export read and write.
    static let storageKey = "camera"
    static let `default` = BoardCamera.broadcast
}
