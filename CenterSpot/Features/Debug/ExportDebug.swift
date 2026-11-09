#if DEBUG
import Foundation

/// Debug-only export hooks for UI tests and the phone: `-exportFrameDelay <ms>` slows every frame so the rendering
/// state can be seen and cancelled; `-exportFails YES` fails the export at frame 10 to show the error state.
enum ExportDebug {
    static let frameDelay = UserDefaults.standard.integer(forKey: "exportFrameDelay")
    static let fails = UserDefaults.standard.bool(forKey: "exportFails")

    static func beforeFrame(_ index: Int) async throws {
        if fails, index == 10 { throw VideoExporter.ExportError.writer("debug: -exportFails") }
        if frameDelay > 0 { try await Task.sleep(for: .milliseconds(frameDelay)) }
    }
}
#endif
