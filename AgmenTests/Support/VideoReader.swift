import AVFoundation
import CoreGraphics
import CryptoKit
import Foundation
import Testing
@testable import Agmen

/// Reads an exported video back with AVFoundation (D5-3): the track's codec, size and nominal frame rate, and every
/// decoded frame as BGRA bytes, so tests check the file and not the exporter's own account of it.
enum VideoReader {
    struct Info {
        let codec: FourCharCode
        let width: Int
        let height: Int
        let nominalFPS: Float
        let duration: Double
        let bytes: Int
    }

    static func info(_ url: URL) async throws -> Info {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let (size, fps, formats) = try await track.load(.naturalSize, .nominalFrameRate, .formatDescriptions)
        let format = try #require(formats.first)
        let duration = try await asset.load(.duration).seconds
        let bytes = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        return Info(codec: CMFormatDescriptionGetMediaSubType(format), width: Int(size.width), height: Int(size.height),
                    nominalFPS: fps, duration: duration, bytes: bytes)
    }

    /// Decodes every frame in order, handing `body` its index and tightly packed BGRA bytes. Returns the frame count.
    @discardableResult
    static func frames(_ url: URL, _ body: (Int, Data) throws -> Void) async throws -> Int {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        reader.add(output)
        #expect(reader.startReading(), "\(String(describing: reader.error))")
        var index = 0
        while let sample = output.copyNextSampleBuffer() {
            guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            try body(index, packed(buffer))
            index += 1
        }
        #expect(reader.status == .completed, "\(String(describing: reader.error))")
        return index
    }

    /// Each decoded frame's SHA-256, for comparing two exports exactly.
    static func digests(_ url: URL) async throws -> [Data] {
        var digests: [Data] = []
        try await frames(url) { _, bytes in digests.append(Data(SHA256.hash(data: bytes))) }
        return digests
    }

    /// The frames at `indices`, decoded.
    static func frames(_ url: URL, at indices: Set<Int>) async throws -> [Int: Data] {
        var found: [Int: Data] = [:]
        try await frames(url) { i, bytes in if indices.contains(i) { found[i] = bytes } }
        return found
    }

    private static func packed(_ buffer: CVPixelBuffer) -> Data {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return Data() }
        var data = Data(capacity: width * height * 4)
        for row in 0..<height { data.append(base.advanced(by: row * stride).assumingMemoryBound(to: UInt8.self), count: width * 4) }
        return data
    }

    /// An image redrawn as tightly packed BGRA bytes, like a decoded frame.
    static func bgra(_ image: CGImage) throws -> Data {
        let w = image.width, h = image.height
        var data = Data(count: w * h * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try data.withUnsafeMutableBytes { buffer in
            let ctx = try #require(CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                             space: space, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                                 | CGBitmapInfo.byteOrder32Little.rawValue))
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return data
    }

    /// The mean absolute difference per colour channel, 0…255.
    static func meanDifference(_ a: Data, _ b: Data) -> Double {
        guard a.count == b.count, a.count >= 4 else { return .infinity }
        var total = 0
        a.withUnsafeBytes { pa in
            b.withUnsafeBytes { pb in
                for i in stride(from: 0, to: a.count, by: 4) {
                    for c in 0..<3 { total += abs(Int(pa[i + c]) - Int(pb[i + c])) }
                }
            }
        }
        return Double(total) / Double(a.count / 4 * 3)
    }

    /// The share of pixels whose colour channels are all within `tolerance` of the other image's.
    static func share(_ a: Data, _ b: Data, within tolerance: Int) -> Double {
        guard a.count == b.count, a.count >= 4 else { return 0 }
        var within = 0
        a.withUnsafeBytes { pa in
            b.withUnsafeBytes { pb in
                for i in stride(from: 0, to: a.count, by: 4) {
                    var off = 0
                    for c in 0..<3 { off = max(off, abs(Int(pa[i + c]) - Int(pb[i + c]))) }
                    if off <= tolerance { within += 1 }
                }
            }
        }
        return Double(within) / Double(a.count / 4)
    }
}
