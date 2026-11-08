import AVFoundation
import CoreGraphics
import Foundation

/// The MP4 export (D-11, SPEC §7): frames from `Timeline` drawn by `ExportFrame` (which draws the board with
/// `BoardRenderer`, D-07) into pixel buffers, then H.264 at 30 fps through `AVAssetWriter` and a pixel buffer adaptor.
/// Runs off the main actor, reports progress per frame, and stops on cancellation, deleting its file.
enum VideoExporter {
    struct Result: Sendable, Equatable {
        let url: URL
        let bytes: Int
        let frames: Int
        /// The video's length in seconds (frames ÷ 30).
        let length: Double
        let format: VideoFormat
        /// Wall-clock seconds the export took, for the timing log.
        let renderSeconds: Double
        let budgetBytes: Double

        /// One line per export for measuring on the phone (`AGMEN-EXPORT …`).
        var logLine: String {
            String(format: "AGMEN-EXPORT format=%@ frames=%d length=%.1fs render=%.2fs size=%.2fMB budget=%.2fMB",
                   format.rawValue, frames, length, renderSeconds, Double(bytes) / 1_000_000, budgetBytes / 1_000_000)
        }
    }

    enum ExportError: Error, Equatable {
        case writer(String)
    }

    /// Where `temporaryURL` makes its per-export folders.
    static var exportsFolder: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    /// A fresh `<title>.mp4` in its own folder under the temporary directory, so the share sheet shows the title.
    static func temporaryURL(title: String, fileExtension: String = "mp4") -> URL {
        let name = title.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return exportsFolder
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name.isEmpty ? "Agmen" : name)
            .appendingPathExtension(fileExtension)
    }

    /// Clears exports an earlier run left behind (the app was closed mid-export). Called once at launch, before any
    /// export can start.
    static func removeLeftovers(in folder: URL = exportsFolder) {
        try? FileManager.default.removeItem(at: folder)
    }

    /// Deletes an export, and the folder `temporaryURL` made for it. A file anywhere else goes alone: its folder
    /// isn't ours to delete.
    static func discard(_ url: URL) {
        let folder = url.deletingLastPathComponent()
        let ours = folder.deletingLastPathComponent().standardizedFileURL.path == exportsFolder.standardizedFileURL.path
        try? FileManager.default.removeItem(at: ours ? folder : url)
    }

    /// Writes `tactic` (phase 0) as a video. `progress` gets (frames written, total) after each frame. On any error or
    /// cancellation the file is deleted before this throws.
    @concurrent
    static func export(_ tactic: Tactic, settings: VideoExportSettings, to url: URL? = nil,
                       progress: @Sendable (Int, Int) -> Void = { _, _ in }) async throws -> Result {
        let url = url ?? temporaryURL(title: tactic.title)
        let clock = ContinuousClock(), start = clock.now
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: url)
            let frames = try await write(tactic, settings: settings, to: url, progress: progress)
            let bytes = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            let length = Double(frames) / Double(ExportClock.fps)
            return Result(url: url, bytes: bytes, frames: frames, length: length, format: settings.format,
                          renderSeconds: start.duration(to: clock.now) / .seconds(1),
                          budgetBytes: settings.budgetBytes(length: length))
        } catch {
            discard(url)
            throw error
        }
    }

    private static func write(_ tactic: Tactic, settings: VideoExportSettings, to url: URL,
                              progress: (Int, Int) -> Void) async throws -> Int {
        let (width, height) = settings.format.pixelSize
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: settings.bitrate,
                AVVideoExpectedSourceFrameRateKey: ExportClock.fps,
                AVVideoMaxKeyFrameIntervalKey: 2 * ExportClock.fps,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ])
        writer.add(input)
        guard writer.startWriting() else { throw failure(writer) }
        writer.startSession(atSourceTime: .zero)

        do {
            let frame = ExportFrame(tactic: tactic, canvas: settings.format.canvas, showsTitle: settings.showsTitle,
                                    showsNotes: settings.showsNotes, camera: settings.camera)
            let duration = frame.duration
            let total = ExportClock.frameCount(duration: duration)
            for index in 0..<total {
                try Task.checkCancellation()
                #if DEBUG
                try await ExportDebug.beforeFrame(index)
                #endif
                while !input.isReadyForMoreMediaData {
                    // A failed writer never becomes ready again; stop instead of waiting forever.
                    guard writer.status == .writing else { throw failure(writer) }
                    try await Task.sleep(for: .milliseconds(2))
                }
                guard let pool = adaptor.pixelBufferPool else { throw failure(writer) }
                var made: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &made) == kCVReturnSuccess, let buffer = made else {
                    throw ExportError.writer("no pixel buffer")
                }
                try draw(frame, at: ExportClock.time(ofFrame: index, duration: duration), into: buffer)
                let time = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(ExportClock.fps))
                guard adaptor.append(buffer, withPresentationTime: time) else { throw failure(writer) }
                progress(index + 1, total)
            }
            input.markAsFinished()
            writer.endSession(atSourceTime: CMTime(value: CMTimeValue(total), timescale: CMTimeScale(ExportClock.fps)))
            await writer.finishWriting()
            guard writer.status == .completed else { throw failure(writer) }
            return total
        } catch {
            if writer.status == .writing { writer.cancelWriting() }
            throw error
        }
    }

    /// Made once, not per frame.
    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)

    /// One frame into a BGRA pixel buffer, through a y-down context like the screen's.
    private static func draw(_ frame: ExportFrame, at t: Double, into buffer: CVPixelBuffer) throws {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        guard let space = sRGB,
              let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { throw ExportError.writer("no bitmap context") }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        frame.draw(at: t, in: ctx)
    }

    private static func failure(_ writer: AVAssetWriter) -> ExportError {
        .writer(writer.error?.localizedDescription ?? "status \(writer.status.rawValue)")
    }
}
