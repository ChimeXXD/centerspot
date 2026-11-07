import Foundation

/// The video sizes (D-11, D-63): 9:16 is the default and the hero; 1:1 and 16:9 are Shoulds.
enum VideoFormat: String, CaseIterable, Sendable, Hashable {
    case vertical, square, wide

    var pixelSize: (width: Int, height: Int) {
        switch self {
        case .vertical: (1080, 1920)
        case .square: (1080, 1080)
        case .wide: (1920, 1080)
        }
    }

    var canvas: ExportCanvas {
        switch self {
        case .vertical: .vertical
        case .square: .square
        case .wide: .wide
        }
    }

    /// "1080 × 1920"
    var sizeText: String { "\(pixelSize.width) × \(pixelSize.height)" }
}

/// Everything a video export can vary. Deliberately no Reduce Motion input (CLAUDE.md rule 8, SPEC §8): the setting
/// changes in-app playback only, so it can never change a video. `VideoExportTests` pins the stored properties.
struct VideoExportSettings: Sendable, Equatable {
    var format: VideoFormat
    /// The tactic's title in the band (UI-BRIEF §4.6 "Title band").
    var showsTitle: Bool
    /// The current step's note, handwritten (UI-BRIEF §4.6 "Step notes").
    var showsNotes: Bool

    init(format: VideoFormat = .vertical, showsTitle: Bool = true, showsNotes: Bool = true) {
        self.format = format
        self.showsTitle = showsTitle
        self.showsNotes = showsNotes
    }

    /// D-11: at most 8 MB (8,000,000 bytes) per 15 s at 1080 × 1920. Other sizes get the same bytes per pixel, so 1:1
    /// gets 56% of it and 16:9 (the same pixel count) all of it.
    static let budgetBytesPer15Seconds = 8_000_000.0
    static let budgetPixels = 1080.0 * 1920.0
    /// The encoder aims this far under the budget, for container overhead and rate-control overshoot.
    static let bitrateHeadroom = 0.85

    var pixelShare: Double {
        min(1, Double(format.pixelSize.width * format.pixelSize.height) / Self.budgetPixels)
    }

    /// The most bytes a video of `length` seconds may take.
    func budgetBytes(length: Double) -> Double {
        Self.budgetBytesPer15Seconds * pixelShare * length / 15
    }

    /// The H.264 average bit rate (bits per second): the budget's rate, less the headroom. 3.63 Mbps at 9:16.
    var bitrate: Int {
        Int(Self.budgetBytesPer15Seconds * 8 / 15 * pixelShare * Self.bitrateHeadroom)
    }

    /// What the sheet shows before export (UI-BRIEF §4.6): the encoder's bit rate over the length. Real files come out
    /// smaller (a still pitch compresses well), and the done state shows the real size.
    func estimatedBytes(length: Double) -> Double {
        Double(bitrate) / 8 * length
    }
}
