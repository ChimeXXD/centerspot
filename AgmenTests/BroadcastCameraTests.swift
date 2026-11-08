import CoreGraphics
import Foundation
import Testing
@testable import Agmen

/// BR-2 (D-65, D-66): the tilted broadcast camera projects the flat pitch plane onto the view. It must match the
/// approved mockup's CSS camera, keep straight lines straight, shrink what is far, follow its target and never show
/// past the touchlines at the bottom of the view.
struct BroadcastCameraTests {
    /// The mockup's `playback--broadcast-3d` frame: a 393 × 516 view, `CAM = { pw: 660, tilt: 54, focus: .34, cx: .34,
    /// persp: 1100, horizon: 0 }`.
    private let view = CGRect(x: 0, y: 0, width: 393, height: 516)
    private var mockup: BroadcastCamera {
        BroadcastCamera(view: view, kind: .full, planeWidth: 660, tiltDegrees: 54, eye: 1100, focus: 0.34, centreX: 0.34)
    }

    /// The oracle: the mockup's CSS, written out. The plane sits with its `focus` row on the view's bottom edge and its
    /// `cx` column on the view's centre, turns by rotateX(tilt) about that row, and is seen through `perspective: eye`
    /// from (centre, 0).
    private func css(_ p: Point, vw: CGFloat = 393, vh: CGFloat = 516, pw: CGFloat = 660, tilt: CGFloat = 54,
                     focus: CGFloat = 0.34, cx: CGFloat = 0.34, eye: CGFloat = 1100) -> CGPoint {
        let ph = pw * 105 / 68, oy = ph * (1 - focus)
        let u = CGFloat(p.x) * pw, v = CGFloat(1 - p.y) * ph
        let a = tilt * .pi / 180
        let x = u - pw / 2, y = v - oy                     // about the transform origin
        let x3 = vw / 2 - (cx - 0.5) * pw + x, y3 = vh + y * cos(a), z = y * sin(a)
        let k = eye / (eye - z)
        return CGPoint(x: vw / 2 + (x3 - vw / 2) * k, y: y3 * k)
    }

    private func expectClose(_ a: CGPoint, _ b: CGPoint, within tolerance: CGFloat = 1e-6,
                             sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(hypot(a.x - b.x, a.y - b.y) <= tolerance, "\(a) is not \(b)", sourceLocation: sourceLocation)
    }

    @Test func itIsTheMockupsCamera() {
        let camera = mockup
        for p in [Point(x: 0.34, y: 0.34), Point(x: 0.08, y: 0.78), Point(x: 0, y: 1), Point(x: 1, y: 1), Point(x: 1, y: 0),
                  Point(x: 0.5, y: 0.5), Point(x: 0.9, y: 0.1)] {
            expectClose(camera.project(camera.plane.point(p)), css(p), within: 1e-6)
        }
        // The worked numbers: the focus point at the bottom centre; 3 at the cross 37% down; the far goal line high.
        expectClose(camera.project(camera.plane.point(Point(x: 0.34, y: 0.34))), CGPoint(x: 196.5, y: 516))
        #expect(abs(camera.project(camera.plane.point(Point(x: 0.08, y: 0.78))).y - 189.8) < 0.2)
        #expect(abs(camera.project(camera.plane.point(Point(x: 0.5, y: 1))).y - 80.7) < 0.2)
    }

    @Test func straightLinesStayStraight() {
        let camera = mockup
        let a = camera.project(camera.plane.point(Point(x: 0.1, y: 0.2)))
        let b = camera.project(camera.plane.point(Point(x: 0.5, y: 0.6)))
        let c = camera.project(camera.plane.point(Point(x: 0.9, y: 1.0)))
        let cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        #expect(abs(cross) < 1e-6 * hypot(c.x - a.x, c.y - a.y) * hypot(c.x - a.x, c.y - a.y))
    }

    @Test func farAwayIsSmaller() {
        let camera = mockup
        let far = camera.depthScale(at: camera.plane.point(Point(x: 0.5, y: 1)))
        let focus = camera.depthScale(at: camera.plane.point(Point(x: 0.5, y: 0.34)))
        let near = camera.depthScale(at: camera.plane.point(Point(x: 0.5, y: 0.1)))
        #expect(far < focus && focus < near, "\(far), \(focus), \(near)")
        #expect(abs(focus - 1) < 1e-9)
        // The touchlines meet toward the far end: the pitch is narrower at the far goal line than at the focus row.
        let farWidth = camera.project(camera.plane.point(Point(x: 1, y: 1))).x - camera.project(camera.plane.point(Point(x: 0, y: 1))).x
        #expect(farWidth < camera.plane.pitchRect.width * 0.8)
    }

    @Test func theLocalTransformIsTheProjectionNearAPoint() {
        let camera = mockup
        let p = camera.plane.point(Point(x: 0.3, y: 0.7))
        let local = camera.local(at: p)
        expectClose(p.applying(local), camera.project(p), within: 1e-6)
        for d in [CGPoint(x: 2, y: 0), CGPoint(x: 0, y: 2), CGPoint(x: -1.5, y: 1.5)] {
            let q = CGPoint(x: p.x + d.x, y: p.y + d.y)
            expectClose(q.applying(local), camera.project(q), within: 0.02)
        }
    }

    @Test func itFollowsItsTarget() {
        let target = Point(x: 0.5, y: 0.6)
        let camera = BroadcastCamera(view: view, kind: .full, target: target)
        let at = camera.project(camera.plane.point(target))
        #expect(abs(at.x - view.midX) < 1e-6)
        // The target sits about where the mockup put the ball: a little over a third of the way down.
        #expect(abs(at.y / view.height - 0.37) < 0.03, "\(at.y / view.height)")
        // In a rect away from the origin it still centres on the target.
        let offset = view.offsetBy(dx: 40, dy: 100)
        let moved = BroadcastCamera(view: offset, kind: .full, target: target)
        expectClose(moved.project(moved.plane.point(target)), CGPoint(x: at.x + 40, y: at.y + 100), within: 1e-6)
    }

    /// Following a ball on the wing, the view stops panning where the touchline meets the bottom corner.
    @Test(arguments: [0.0, 1.0])
    func itNeverPansPastATouchline(x: Double) {
        let camera = BroadcastCamera(view: view, kind: .full, target: Point(x: x, y: 0.5))
        let line = camera.project(camera.plane.point(Point(x: x, y: camera.focus)))
        if x == 0 { #expect(line.x <= view.minX + 1e-6, "\(line)") } else { #expect(line.x >= view.maxX - 1e-6, "\(line)") }
        #expect(abs(line.y - view.maxY) < 1e-6)
    }

    /// From anywhere on the pitch, every corner of every kind projects in front of the eye.
    @Test func theEyeIsAlwaysInFrontOfThePitch() {
        for kind in Pitch.Kind.allCases {
            for size in [CGSize(width: 393, height: 516), CGSize(width: 1920, height: 1080), CGSize(width: 1024, height: 1100)] {
                for tx in [0.0, 0.5, 1.0] { for ty in [0.0, 0.5, 1.0] {
                    let camera = BroadcastCamera(view: CGRect(origin: .zero, size: size), kind: kind, target: Point(x: tx, y: ty))
                    for corner in [Point(x: 0, y: 0), Point(x: 1, y: 0), Point(x: 0, y: 1), Point(x: 1, y: 1)] {
                        let k = camera.depthScale(at: camera.plane.point(corner))
                        #expect(k > 0 && k < 6, "\(kind) \(size) target \(tx),\(ty) corner \(corner): \(k)")
                    }
                } }
            }
        }
    }

    @Test func aWideViewUsesTheWideLens() {
        let wide = BroadcastCamera(view: CGRect(x: 0, y: 0, width: 1920, height: 1080), kind: .full, target: .centre)
        let tall = BroadcastCamera(view: CGRect(x: 0, y: 0, width: 1080, height: 1544), kind: .full, target: .centre)
        #expect(wide.lens == .wide)
        #expect(tall.lens == .standard)
        // The whole width shows in the wide view, so it doesn't pan sideways.
        #expect(BroadcastCamera(view: CGRect(x: 0, y: 0, width: 1920, height: 1080), kind: .full, target: Point(x: 0.1, y: 0.5)).centreX == 0.5)
    }

    @Test func pathsAreProjectedPointByPoint() {
        let camera = mockup
        let rect = CGRect(x: 100, y: 200, width: 300, height: 400)
        let quad = camera.project(CGPath(rect: rect, transform: nil))
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)].map(camera.project)
        let box = corners.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
        #expect(abs(quad.boundingBoxOfPath.minX - box.minX) < 1e-6 && abs(quad.boundingBoxOfPath.maxY - box.maxY) < 1e-6)
        // A circle becomes the projected circle: every point of the path lies on the projected ring.
        let centre = camera.plane.point(Point(x: 0.4, y: 0.6)), r: CGFloat = 30
        let ring = camera.project(CGPath(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r),
                                         transform: nil))
        let samples = (0..<72).map { i -> CGPoint in
            let a = CGFloat(i) / 72 * 2 * .pi
            return camera.project(CGPoint(x: centre.x + r * cos(a), y: centre.y + r * sin(a)))
        }
        let expected = samples.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
        let got = ring.boundingBoxOfPath
        #expect(abs(got.minX - expected.minX) < 0.5 && abs(got.maxX - expected.maxX) < 0.5
                && abs(got.minY - expected.minY) < 0.5 && abs(got.maxY - expected.maxY) < 0.5, "\(got) vs \(expected)")
    }
}
