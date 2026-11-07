#if DEBUG
import AVFoundation
import CoreGraphics
import CoreText
import Foundation

/// D2-6, throwaway: how fast and how big is a 1080 × 1920, 30 fps H.264 export on this device (D-11)?
/// Launch with `-exportSpike`; results print as `AGMEN-SPIKE …`. VideoExporter replaces this on Day 5.
enum ExportSpike {
    struct Result: Sendable, CustomStringConvertible {
        let frames: Int, bitrate: Int, seconds: Double, bytes: Int
        var description: String {
            String(format: "AGMEN-SPIKE frames=%d video=%.1fs bitrate=%.1fMbps render=%.2fs size=%.2fMB", frames,
                   Double(frames) / 30, Double(bitrate) / 1_000_000, seconds, Double(bytes) / 1_000_000)
        }
    }

    static func report() async {
        for (frames, bitrate) in [(240, 4_000_000), (450, 4_000_000), (450, 3_000_000)] {
            do { print(try await run(frames: frames, bitrate: bitrate)) } catch { print("AGMEN-SPIKE failed: \(error)") }
        }
        print("AGMEN-SPIKE done")
    }

    static func run(frames: Int, bitrate: Int) async throws -> Result {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("spike-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1080, AVVideoHeightKey: 1920,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate, AVVideoExpectedSourceFrameRateKey: 30, AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 1080, kCVPixelBufferHeightKey as String: 1920,
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)

        let numbers = shirtNumbers()
        let clock = ContinuousClock(), start = clock.now  // measures the export, not the board's timeline
        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData {
                // A failed writer never becomes ready again; stop instead of spinning forever.
                guard writer.status == .writing else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
                try await Task.sleep(for: .milliseconds(2))
            }
            var buffer: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool,
                  CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else {
                throw CocoaError(.fileWriteUnknown)
            }
            draw(frame: frame, of: frames, numbers: numbers, into: buffer)
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) else {
                throw writer.error ?? CocoaError(.fileWriteUnknown)
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        let seconds = start.duration(to: clock.now) / .seconds(1)
        let bytes = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return Result(frames: frames, bitrate: bitrate, seconds: seconds, bytes: bytes)
    }

    private static let colourSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    /// Shirt numbers 1…11, built once per run so the timing measures drawing rather than font and line setup.
    private static func shirtNumbers() -> [CTLine] {
        let font = CTFontCreateWithName(Tokens.Typeface.uiName as CFString, 34, nil)
        return (1...11).map { n in
            CTLineCreateWithAttributedString(NSAttributedString(string: "\(n)", attributes: [
                .font: font, .foregroundColor: Tokens.Colour.bg.cgColor,
            ]))
        }
    }

    /// About the work of a real frame: striped pitch, chalk lines, 23 moving discs with numbers.
    private static func draw(frame: Int, of frames: Int, numbers: [CTLine], into buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: 1080, height: 1920, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: colourSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }
        context.setFillColor(Tokens.Colour.bg.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 1080, height: 1920))
        let pitch = CGRect(x: 40, y: 260, width: 1000, height: 1000 * 105 / 68)
        for i in 0..<10 {
            context.setFillColor((i.isMultiple(of: 2) ? Tokens.Colour.pitchA : Tokens.Colour.pitchB).cgColor)
            context.fill(CGRect(x: pitch.minX, y: pitch.minY + CGFloat(i) * pitch.height / 10, width: pitch.width, height: pitch.height / 10))
        }
        context.setStrokeColor(Tokens.Colour.chalk.cgColor)
        context.setLineWidth(4)
        context.stroke(pitch)
        context.strokeEllipse(in: CGRect(x: pitch.midX - 135, y: pitch.midY - 135, width: 270, height: 270))
        let t = Double(frame) / Double(max(frames - 1, 1))
        for i in 0..<23 {
            let x = pitch.minX + pitch.width * (0.1 + 0.8 * Double((i * 37) % 23) / 22) + 60 * sin(t * 6 + Double(i))
            let y = pitch.minY + pitch.height * (0.08 + 0.84 * Double(i) / 22) + 80 * cos(t * 5 + Double(i))
            context.setFillColor(Tokens.kit(i < 11 ? .lime : .coral).fill.cgColor)
            context.fillEllipse(in: CGRect(x: x - 32, y: y - 32, width: 64, height: 64))
            context.textPosition = CGPoint(x: x - 10, y: y - 12)
            CTLineDraw(numbers[i % 11], context)
        }
    }
}
#endif
