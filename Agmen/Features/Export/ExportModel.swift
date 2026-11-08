import Foundation
import Observation
import Photos

/// The export sheet's state (UI-BRIEF §4.6, mockup "export" screens): the preset and switches, then rendering with an
/// honest frame count, then the real file and its size, or an error with a way out. The work runs in `VideoExporter`
/// and `ImageExporter`, off the main actor; this only follows it.
@MainActor @Observable
final class ExportModel {
    enum Preset: String, CaseIterable, Identifiable {
        case vertical, square, wide, image

        var id: String { rawValue }
        var title: String {
            switch self {
            case .vertical: "Vertical 9:16"
            case .square: "Square 1:1"
            case .wide: "Wide 16:9"
            case .image: "Image"
            }
        }
        var video: VideoFormat? { VideoFormat(rawValue: rawValue) }
    }

    enum ImageKind: Hashable { case step, lineup }

    struct File: Equatable {
        let url: URL
        let bytes: Int
        /// "4.0 MB · 8 s · 1080 × 1920"
        let summary: String
        let isVideo: Bool
    }

    enum Phase: Equatable {
        case choosing
        case rendering(done: Int, total: Int)
        case finished(File)
        case failed
    }

    enum PhotosState: Equatable { case idle, saving, saved, failed }

    let tactic: Tactic
    /// The step on screen, for the step image and the preview's still.
    let stepIndex: Int
    /// The board's on-screen width in points; the step PNG is twice it in pixels (SPEC §7).
    let boardWidth: CGFloat

    var preset = Preset.vertical
    var showsTitle = true
    var showsNotes = true
    var imageKind = ImageKind.step
    /// Videos only; images stay flat. Shared with playback's switch and remembered (D-76).
    var camera = BoardCamera(rawValue: UserDefaults.standard.string(forKey: BoardCamera.storageKey) ?? "") ?? .default {
        didSet { UserDefaults.standard.set(camera.rawValue, forKey: BoardCamera.storageKey) }
    }
    private(set) var phase = Phase.choosing
    private(set) var photos = PhotosState.idle
    /// The sheet closed while Photos was still saving: the file goes once the save is done, not mid-save.
    private var discardAfterSave = false
    private var started: ContinuousClock.Instant?
    private var task: Task<Void, Never>?

    init(tactic: Tactic, stepIndex: Int, boardWidth: CGFloat) {
        self.tactic = tactic
        self.stepIndex = stepIndex
        self.boardWidth = boardWidth
    }

    var settings: VideoExportSettings {
        VideoExportSettings(format: preset.video ?? .vertical, showsTitle: showsTitle, showsNotes: showsNotes, camera: camera)
    }

    var duration: Double { tactic.phases.first.map(Timeline.duration(of:)) ?? 0 }
    var length: Double { ExportClock.length(duration: duration) }

    /// The PNG's pixel size before it is made.
    var imageSize: (width: Int, height: Int) {
        if imageKind == .lineup { return (Int(LineupCard.size.width), Int(LineupCard.size.height)) }
        let width = ImageExporter.pixelWidth(boardWidth: boardWidth)
        let layout = ExportLayout.make(.image(width: width), kind: tactic.pitch.kind, showsTitle: showsTitle, showsNote: showsNotes)
        return (width, Int(layout.canvas.height))
    }

    /// Before export: "Up to 4 MB · 8 s · 1080 × 1920", or "PNG · 708 × 1259". The video figure is the encoder's
    /// budget, a ceiling: real clips come out about a quarter of it (1.1 MB of 4.3 MB for the hero on the iPhone 14
    /// Pro), and the real size is shown before sharing (rule 7).
    var estimate: String {
        guard let format = preset.video else { return "PNG · \(imageSize.width) × \(imageSize.height)" }
        return "Up to \(Self.megabytes(settings.estimatedBytes(length: length), rounded: true)) · "
            + "\(BoardContextRow.seconds(length)) · \(format.sizeText)"
    }

    var estimateHelp: String {
        if preset.video != nil { return "Estimate. Plays in WhatsApp and Discord." }
        return imageKind == .lineup ? "A team sheet: the shape, numbers and names." : "Twice the board's size on screen."
    }

    var progressText: String {
        guard case .rendering(let done, let total) = phase else { return "" }
        if preset.video == nil { return "Making the image" }
        return "Rendering \(done) of \(total) frames"
    }

    /// "About 3 seconds left. Keep Agmen open until it's done."
    var remainingText: String {
        let keepOpen = "Keep Agmen open until it's done."
        guard case .rendering(let done, let total) = phase, done >= 10, let started else { return keepOpen }
        let elapsed = started.duration(to: .now) / .seconds(1)
        let left = elapsed / Double(done) * Double(total - done)
        if left < 1.5 { return "Almost done. \(keepOpen)" }
        return "About \(Int(left.rounded())) seconds left. \(keepOpen)"
    }

    var progress: Double {
        guard case .rendering(let done, let total) = phase, total > 0 else { return 0 }
        return Double(done) / Double(total)
    }

    // MARK: Actions

    func start() {
        task?.cancel()
        photos = .idle
        started = .now
        if let format = preset.video {
            phase = .rendering(done: 0, total: ExportClock.frameCount(duration: duration))
            task = Task { await renderVideo(format) }
        } else {
            phase = .rendering(done: 0, total: 1)
            task = Task { await renderImage() }
        }
    }

    /// Stops the export; `VideoExporter` deletes its temporary file.
    func cancel() {
        task?.cancel()
        task = nil
        phase = .choosing
    }

    /// The error's way out: pick the image preset.
    func chooseImage() {
        preset = .image
        phase = .choosing
    }

    /// The sheet is closing: stop any export and delete a finished file (the share sheet has made its own copy).
    func close() {
        task?.cancel()
        if case .finished(let file) = phase {
            if photos == .saving { discardAfterSave = true } else { VideoExporter.discard(file.url) }
        }
        phase = .choosing
    }

    func saveToPhotos() async {
        // A second tap can land before the button disables: save each file once.
        guard case .finished(let file) = phase, photos != .saving, photos != .saved else { return }
        photos = .saving
        defer {
            if discardAfterSave {
                discardAfterSave = false
                VideoExporter.discard(file.url)
            }
        }
        guard await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized else { photos = .failed; return }
        do {
            try await Self.addToPhotos(file.url, isVideo: file.isVideo)
            photos = .saved
        } catch {
            photos = .failed
        }
    }

    /// Photos runs the change block on its own queue. Built here, outside the main actor, the block isn't tied to it;
    /// written inline in `saveToPhotos` it inherited main-actor isolation and Swift's runtime check stopped the app
    /// when Photos called it (Chime's phone, 7 Nov). `@concurrent` keeps it off the caller's actor even if
    /// nonisolated async functions later default to running on the caller (SE-0461).
    @concurrent nonisolated private static func addToPhotos(_ url: URL, isVideo: Bool) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: isVideo ? .video : .photo, fileURL: url, options: nil)
        }
    }

    // MARK: Work

    private func renderVideo(_ format: VideoFormat) async {
        let (frames, report) = AsyncStream.makeStream(of: (Int, Int).self, bufferingPolicy: .bufferingNewest(1))
        async let exported = Self.export(tactic, settings: settings, report: report)
        // A cancelled stream can still hand over one buffered count; it must not undo Cancel's `.choosing`.
        for await (done, total) in frames {
            guard !Task.isCancelled else { break }
            phase = .rendering(done: done, total: total)
        }
        do {
            let result = try await exported
            #if DEBUG
            print(result.logLine + " steps=\(tactic.phases.first?.steps.count ?? 0)")
            #endif
            guard !Task.isCancelled else { VideoExporter.discard(result.url); return }
            phase = .finished(File(url: result.url, bytes: result.bytes,
                                   summary: "\(Self.megabytes(Double(result.bytes))) · \(BoardContextRow.seconds(result.length)) · "
                                       + format.sizeText,
                                   isVideo: true))
        } catch is CancellationError {
            if !Task.isCancelled { phase = .choosing }
        } catch {
            #if DEBUG
            print("AGMEN-EXPORT failed format=\(format.rawValue): \(error)")
            #endif
            if !Task.isCancelled { phase = .failed }
        }
    }

    /// The exporter, finishing the progress stream however it ends.
    nonisolated private static func export(_ tactic: Tactic, settings: VideoExportSettings,
                                           report: AsyncStream<(Int, Int)>.Continuation) async throws -> VideoExporter.Result {
        defer { report.finish() }
        return try await VideoExporter.export(tactic, settings: settings) { done, total in report.yield((done, total)) }
    }

    private func renderImage() async {
        do {
            let result = imageKind == .lineup
                ? try await ImageExporter.exportLineup(tactic)
                : try await ImageExporter.exportStep(tactic, step: stepIndex, boardWidth: boardWidth,
                                                     showsTitle: showsTitle, showsNotes: showsNotes)
            guard !Task.isCancelled else { VideoExporter.discard(result.url); return }
            phase = .finished(File(url: result.url, bytes: result.bytes,
                                   summary: "\(Self.megabytes(Double(result.bytes))) · \(result.width) × \(result.height)",
                                   isVideo: false))
        } catch {
            if !Task.isCancelled { phase = .failed }
        }
    }

    /// "4.0 MB" (1 MB = 1,000,000 bytes, as Files and WhatsApp count); rounded to whole megabytes for estimates.
    static func megabytes(_ bytes: Double, rounded: Bool = false) -> String {
        let mb = bytes / 1_000_000
        if rounded, mb >= 1 { return "\(Int(mb.rounded())) MB" }
        return "\(mb.formatted(.number.precision(.fractionLength(1)))) MB"
    }
}
