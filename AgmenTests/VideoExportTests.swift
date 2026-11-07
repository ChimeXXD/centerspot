import AVFoundation
import Foundation
import Synchronization
import Testing
@testable import Agmen

/// D5-3, SPEC §7 and §10: the exported file, read back with AVFoundation, is H.264 at the format's size and 30 fps, has
/// `30 × (0.5 + duration + 1.0)` frames (±1), fits `8 MB × length ÷ 15 s` (scaled by pixels for 1:1), opens and ends on
/// stills, comes out the same twice, and a cancelled export leaves no file. Serialized: each export uses the encoder.
@Suite(.serialized)
struct VideoExportTests {
    // MARK: The plan (pure)

    @Test func theFramePlanIsALeadInTheMoveAndAnEndStill() {
        #expect(ExportClock.frameCount(duration: 6.5) == 240, "the hero: 0.5 + 6.5 + 1.0 s at 30 fps")
        for d in [0.0, 0.3, 1.23, 6.5, 7.77, 41.1] {
            let n = ExportClock.frameCount(duration: d)
            #expect(abs(Double(n) - 30 * (0.5 + d + 1.0)) <= 1, "\(d) s → \(n) frames")
        }
        let d = 6.5, n = ExportClock.frameCount(duration: d)
        #expect((0..<15).allSatisfy { ExportClock.time(ofFrame: $0, duration: d) == 0 }, "0.5 s lead-in at t = 0")
        #expect(ExportClock.time(ofFrame: 15, duration: d) > 0, "the move starts after it")
        #expect(((n - 30)..<n).allSatisfy { ExportClock.time(ofFrame: $0, duration: d) == d }, "1 s end still")
        #expect(ExportClock.time(ofFrame: n - 31, duration: d) == d, "the move's last frame lands on its last instant")
        #expect(ExportClock.time(ofFrame: n - 32, duration: d) < d)
        let times = (0..<n).map { ExportClock.time(ofFrame: $0, duration: d) }
        #expect(zip(times, times.dropFirst()).allSatisfy { $0 <= $1 }, "never backwards")
        #expect(abs(ExportClock.length(duration: d) - 8) < 1e-9)
    }

    /// CLAUDE.md rule 8: the exporter's configuration has no Reduce Motion input, so the setting can't change a video.
    /// Compile-level: the initialiser below names every input; a new stored property must also appear in the list.
    @Test func theSettingsHaveNoReduceMotionInput() {
        let settings = VideoExportSettings(format: .vertical, showsTitle: true, showsNotes: true, spotlight: nil)
        let stored = Mirror(reflecting: settings).children.compactMap(\.label)
        #expect(stored == ["format", "showsTitle", "showsNotes", "spotlight"])
        #expect(!stored.contains { $0.lowercased().contains("motion") || $0.lowercased().contains("reduce") })
    }

    /// D-11: 8 MB per 15 s at 1080 × 1920; the encoder aims under it in every format.
    @Test(arguments: VideoFormat.allCases)
    func theBitrateFitsTheBudget(format: VideoFormat) {
        let settings = VideoExportSettings(format: format)
        let rule = 8_000_000.0 * min(1, Double(format.pixelSize.width * format.pixelSize.height) / (1080 * 1920))
        #expect(settings.budgetBytes(length: 15) == rule)
        #expect(Double(settings.bitrate) / 8 * 15 <= rule * 0.9, "\(settings.bitrate) bps")
        #expect(settings.bitrate >= 1_500_000, "not starved: \(settings.bitrate) bps")
    }

    // MARK: The file

    @Test(arguments: VideoFormat.allCases)
    func theHeroExportsAsSpecified(format: VideoFormat) async throws {
        let hero = try Fixtures.tactic("overlap-left")
        try await checkExport(of: hero, format: format, name: "hero")
    }

    @Test(arguments: VideoFormat.allCases)
    func aTenStepMoveExportsAsSpecified(format: VideoFormat) async throws {
        let ten = ExportBench.tenStepMove(from: try Fixtures.tactic("overlap-left"))
        try #require(ten.phases.first?.steps.count == 10)
        try await checkExport(of: ten, format: format, name: "ten-steps")
    }

    private func checkExport(of tactic: Tactic, format: VideoFormat, name: String) async throws {
        let settings = VideoExportSettings(format: format)
        let result = try await VideoExporter.export(tactic, settings: settings)
        defer { VideoExporter.discard(result.url) }
        print("\(result.logLine) move=\(name)")
        let info = try await VideoReader.info(result.url)
        #expect(info.codec == kCMVideoCodecType_H264)
        #expect(info.width == format.pixelSize.width && info.height == format.pixelSize.height, "\(info.width)×\(info.height)")
        #expect(abs(info.nominalFPS - 30) < 0.01, "\(info.nominalFPS) fps")
        let duration = Timeline.duration(of: try #require(tactic.phases.first))
        let frames = try await VideoReader.frames(result.url) { _, _ in }
        #expect(abs(Double(frames) - 30 * (0.5 + duration + 1.0)) <= 1, "\(frames) frames for a \(duration) s move")
        #expect(frames == result.frames)
        #expect(abs(info.duration - Double(frames) / 30) < 0.001, "\(info.duration) s")
        #expect(Double(info.bytes) <= settings.budgetBytes(length: info.duration), "\(info.bytes) bytes")
        #expect(info.bytes == result.bytes)
    }

    /// The first 15 frames show the board at t = 0 and the last 30 the board at the end: compared with the frames
    /// `ExportFrame` draws, allowing for H.264's loss at colour edges (≥ 98% within 32/255), and the start is not the end.
    @Test func itOpensAndEndsOnStills() async throws {
        let hero = try Fixtures.tactic("overlap-left")
        let result = try await VideoExporter.export(hero, settings: VideoExportSettings())
        defer { VideoExporter.discard(result.url) }
        let n = result.frames
        let decoded = try await VideoReader.frames(result.url, at: [0, 14, n - 30, n - 1])
        let frame = ExportFrame(tactic: hero, canvas: .vertical, showsTitle: true, showsNotes: true)
        let start = try VideoReader.bgra(try #require(frame.image(at: 0)))
        let end = try VideoReader.bgra(try #require(frame.image(at: frame.duration)))
        for i in [0, 14] {
            let share = VideoReader.share(try #require(decoded[i]), start, within: 32)
            #expect(share >= 0.98, "frame \(i) vs t = 0: \(share)")
        }
        for i in [n - 30, n - 1] {
            let share = VideoReader.share(try #require(decoded[i]), end, within: 32)
            #expect(share >= 0.98, "frame \(i) vs the end: \(share)")
        }
        let blind = VideoReader.share(try #require(decoded[0]), end, within: 32)
        #expect(blind < 0.98, "the check can tell the start from the end: \(blind)")

        // Still means still, for the whole 0.5 s and 1 s: the last lead-in frame is nearer the board at t = 0 than at
        // 0.5 s, and the first end frame nearer the end than half a second before it. (Decoded stills aren't byte-equal:
        // the encoder keeps refining a still picture. Comparing one decoded frame with two renders cancels that noise.)
        let half = try VideoReader.bgra(try #require(frame.image(at: 0.5)))
        let beforeEnd = try VideoReader.bgra(try #require(frame.image(at: frame.duration - 0.5)))
        let lastLeadIn = try #require(decoded[14]), firstEnd = try #require(decoded[n - 30])
        #expect(VideoReader.meanDifference(lastLeadIn, start) < VideoReader.meanDifference(lastLeadIn, half),
                "frame 14 shows t = 0")
        #expect(VideoReader.meanDifference(firstEnd, end) < VideoReader.meanDifference(firstEnd, beforeEnd),
                "frame \(n - 30) shows the end")
    }

    /// Two exports of the hero decode to the same frames, compared exactly (SHA-256 of every decoded frame): the frames
    /// are a pure function of t (`Timeline`, `ExportFrame`) and the encoder is given identical input and settings, so
    /// any difference at all would be a bug, not noise.
    @Test func twoExportsDecodeToIdenticalFrames() async throws {
        let hero = try Fixtures.tactic("overlap-left")
        let a = try await VideoExporter.export(hero, settings: VideoExportSettings())
        defer { VideoExporter.discard(a.url) }
        let b = try await VideoExporter.export(hero, settings: VideoExportSettings())
        defer { VideoExporter.discard(b.url) }
        let first = try await VideoReader.digests(a.url), second = try await VideoReader.digests(b.url)
        #expect(first.count == 240)
        #expect(first == second, "\(zip(first, second).filter { $0 != $1 }.count) frames differ")
    }

    /// D5-4: Cancel stops the export and deletes the file and its folder. Called from the main actor, the frames are
    /// still made off it.
    @Test @MainActor func cancellingStopsAndDeletesTheFile() async throws {
        let hero = try Fixtures.tactic("overlap-left")
        let url = VideoExporter.temporaryURL(title: "Cancel me")
        let offMain = Mutex(true)
        let (written, report) = AsyncStream.makeStream(of: Int.self)
        let export = Task {
            try await VideoExporter.export(hero, settings: VideoExportSettings(), to: url) { n, _ in
                if Thread.isMainThread { offMain.withLock { $0 = false } }
                report.yield(n)
            }
        }
        var seen = 0
        for await n in written {
            seen = n
            if n >= 30 { break }
        }
        #expect(seen >= 30)
        #expect(FileManager.default.fileExists(atPath: url.path), "the export had started writing")
        export.cancel()
        switch await export.result {
        case .success(let result):
            Issue.record("finished anyway: \(result.frames) frames")
            VideoExporter.discard(result.url)
        case .failure(let error):
            #expect(error is CancellationError, "\(error)")
        }
        #expect(!FileManager.default.fileExists(atPath: url.path), "no file left")
        #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path), "no folder left")
        #expect(offMain.withLock { $0 }, "frames were made on the main thread")
    }

    /// An export the app was killed during leaves its folder behind; the next launch clears them all. (Its own
    /// folder, so parallel tests' exports in the real one are untouched.)
    @Test func leftoverExportsAreClearedOnLaunch() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ExportsTest-\(UUID().uuidString)")
        let leftover = folder.appendingPathComponent(UUID().uuidString).appendingPathComponent("Left behind.mp4")
        try FileManager.default.createDirectory(at: leftover.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: leftover)
        VideoExporter.removeLeftovers(in: folder)
        #expect(!FileManager.default.fileExists(atPath: leftover.path))
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }
}
