import CoreGraphics
import Foundation

/// The tilted broadcast camera (D-65, D-66, BR-2): the mockup's CSS camera as maths. The pitch is laid flat on a
/// plane (`plane`, the board in its own points), turned away from the viewer about the row at the view's bottom edge,
/// and seen in perspective from above the view's top centre. `project` takes a point on the plane to the view; a
/// straight line stays straight, so polygons project by their corners and curves are flattened first.
struct BroadcastCamera: Sendable, Equatable {
    /// How a view frames the pitch, from the approved mockup frames (`mockup/screens-broadcast.js`).
    struct Lens: Sendable, Equatable {
        var tiltDegrees: Double
        /// The plane is as wide as the smaller of these times the view's width and height.
        var widthPerViewWidth: CGFloat
        var widthPerViewHeight: CGFloat
        /// The eye's distance from the view, in plane widths (CSS `perspective`).
        var eye: CGFloat
        /// How far up the pitch (0…1 of its length) the target sits above the view's bottom edge.
        var lead: Double

        /// Tall views (playback, the 9:16 frame): touchline to touchline across the middle of the view, the camera
        /// steeper than the mockup's `CAM = { pw: 660, tilt: 54, persp: 1100 }` so the pitch still runs past the view
        /// and the camera follows play (D-91, Chime picked "B" from renders on the iPhone and iPad). The plane is at
        /// most 1.1 view widths, and narrower in a squarer view (0.84 view heights).
        static let standard = Lens(tiltDegrees: 35, widthPerViewWidth: 1.1, widthPerViewHeight: 0.84,
                                   eye: 1100 / 660, lead: 0.44)
        /// Wide views (16:9): `{ pw: 320, tilt: 58, persp: 700 }` in a 393 × 221 view.
        static let wide = Lens(tiltDegrees: 58, widthPerViewWidth: 320 / 393, widthPerViewHeight: 320 / 221,
                               eye: 700 / 320, lead: 0.42)

        /// A view at least this much wider than tall takes the wide lens.
        static let wideAspect: CGFloat = 1.4

        static func fitting(_ size: CGSize) -> Lens {
            size.height > 0 && size.width / size.height >= wideAspect ? .wide : .standard
        }
    }

    /// The lowest the bottom edge may sit: a little behind the near goal line.
    static let lowestFocus = -0.05

    let view: CGRect
    /// The pitch flat on the plane, at the plane's origin; everything on the grass is drawn in these points.
    let plane: BoardGeometry
    let lens: Lens
    /// The pitch row (0…1 up the pitch) on the view's bottom edge, and the pitch column at the view's centre.
    let focus: Double
    let centreX: Double
    private let eye: CGFloat
    private let cosTilt: CGFloat
    private let sinTilt: CGFloat
    /// The focus row on the plane, in plane points from its top.
    private let focusRow: CGFloat

    /// The camera in the mockup's own terms (its `CAM` values): for tests against the mockup.
    init(view: CGRect, kind: Pitch.Kind, planeWidth: CGFloat, tiltDegrees: Double, eye: CGFloat, focus: Double,
         centreX: Double, lens: Lens = .standard) {
        let height = BoardGeometry.height(forWidth: planeWidth, kind: kind)
        self.view = view
        self.lens = lens
        plane = BoardGeometry(pitchRect: CGRect(x: 0, y: 0, width: planeWidth, height: height))
        self.focus = focus
        self.centreX = centreX
        self.eye = eye
        let tilt = CGFloat(tiltDegrees * .pi / 180)
        cosTilt = cos(tilt)
        sinTilt = sin(tilt)
        focusRow = height * CGFloat(1 - focus)
    }

    /// The camera looking at `target` (a point on the pitch, `CameraTrack`): the target on the view's centre line,
    /// `lens.lead` above the bottom edge, without panning past a touchline at the bottom corners, or so far up the
    /// pitch that the far goal line comes down into the view with empty dark above it (D-91).
    init(view: CGRect, kind: Pitch.Kind, target: Point) {
        let lens = Lens.fitting(view.size)
        var width = max(min(lens.widthPerViewWidth * view.width, lens.widthPerViewHeight * view.height), 1)
        func camera(width: CGFloat, focus: Double) -> BroadcastCamera {
            let half = Double(view.width / (2 * width))
            let x = half >= 0.5 ? 0.5 : target.x.clamped(to: half...(1 - half))
            return BroadcastCamera(view: view, kind: kind, planeWidth: width, tiltDegrees: lens.tiltDegrees,
                                   eye: lens.eye * width, focus: focus, centreX: x, lens: lens)
        }
        // A view taller than the lens was made for shows the whole pitch with dark above it even from the lowest
        // camera: draw the pitch bigger, 3% at a time, until the far goal line reaches the top (D-91).
        for _ in 0..<40 where !Self.skyFree(camera(width: width, focus: Self.lowestFocus)) { width *= 1.03 }
        let highest = Self.highestFocus(below: 1 - lens.lead) { camera(width: width, focus: $0) }
        self = camera(width: width, focus: (target.y - lens.lead).clamped(to: Self.lowestFocus...max(highest, Self.lowestFocus)))
    }

    /// How far below the view's top edge the far goal line may sit, as a share of the view's height.
    static let skyMargin: CGFloat = 0.03

    /// The highest bottom edge (at most `limit`) that keeps the far goal line within `skyMargin` of the view's top:
    /// the far line comes down the view as the camera looks farther up the pitch, so bisect.
    private static func highestFocus(below limit: Double, _ make: (Double) -> BroadcastCamera) -> Double {
        guard !skyFree(make(limit)) else { return limit }
        var low = lowestFocus, high = limit
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if skyFree(make(mid)) { low = mid } else { high = mid }
        }
        return low
    }

    /// Whether the far goal line is within `skyMargin` of the view's top.
    private static func skyFree(_ camera: BroadcastCamera) -> Bool {
        let far = camera.project(camera.plane.point(Point(x: 0.5, y: 1)))
        return far.y <= camera.view.minY + skyMargin * camera.view.height
    }

    /// How far round the moving area (0…1 of the pitch) the still view keeps in sight: a disc and its glow.
    static let framingMargin = 0.05

    /// Reduce Motion's still view (D-76): the normal framing of `span`'s middle when that shows all of it, else the
    /// pitch drawn smaller, 5% at a time, until `span` and `framingMargin` round it are inside the view. Nearer the
    /// bottom edge than the normal lead when the area is deep, so its near side isn't cut off.
    init(view: CGRect, kind: Pitch.Kind, framing span: CameraTrack.Span) {
        let follow = BroadcastCamera(view: view, kind: kind, target: span.middle)
        guard !follow.shows(span) else {
            self = follow
            return
        }
        let lens = Lens.fitting(view.size)
        let full = max(min(lens.widthPerViewWidth * view.width, lens.widthPerViewHeight * view.height), 1)
        let focus = min(span.middle.y - lens.lead, span.min.y - Self.framingMargin)
            .clamped(to: Self.lowestFocus...(1 - lens.lead))
        var camera = follow
        for step in 1...16 {
            let width = full * (1 - 0.05 * CGFloat(step))
            camera = BroadcastCamera(view: view, kind: kind, planeWidth: width, tiltDegrees: lens.tiltDegrees,
                                     eye: lens.eye * width, focus: focus, centreX: span.middle.x, lens: lens)
            if camera.shows(span) { break }
        }
        self = camera
    }

    /// Whether `span`, with `framingMargin` round it, projects inside the view.
    func shows(_ span: CameraTrack.Span) -> Bool {
        let m = Self.framingMargin, bounds = view.insetBy(dx: -0.5, dy: -0.5)
        return [Point(x: span.min.x - m, y: span.min.y - m), Point(x: span.max.x + m, y: span.min.y - m),
                Point(x: span.min.x - m, y: span.max.y + m), Point(x: span.max.x + m, y: span.max.y + m)]
            .allSatisfy { bounds.contains(project(plane.point($0))) }
    }

    /// A point on the plane, in the view.
    func project(_ p: CGPoint) -> CGPoint {
        let (x, y, k) = parts(p)
        return CGPoint(x: view.minX + view.width / 2 + x * k, y: view.minY + (view.height + y * cosTilt) * k)
    }

    /// How much bigger than on the plane something at `p` is drawn: 1 on the bottom edge's row, less farther away.
    func depthScale(at p: CGPoint) -> CGFloat { parts(p).k }

    /// The projection near `p` as an affine transform (its derivative there): small things drawn flat on the grass
    /// around `p` (a disc, a glow) come out the shape the camera sees them.
    func local(at p: CGPoint) -> CGAffineTransform {
        let (x, y, k) = parts(p)
        let dk = k * k * sinTilt / eye  // dk/dy
        let a = k, c = x * dk, d = cosTilt * k + (view.height + y * cosTilt) * dk
        let at = project(p)
        return CGAffineTransform(a: a, b: 0, c: c, d: d, tx: at.x - a * p.x - c * p.y, ty: at.y - d * p.y)
    }

    /// A path on the plane, in the view: lines by their ends, curves flattened into short lines first.
    func project(_ path: CGPath) -> CGPath {
        let out = CGMutablePath()
        var current = CGPoint.zero, start = CGPoint.zero
        path.applyWithBlock { element in
            let e = element.pointee
            switch e.type {
            case .moveToPoint:
                current = e.points[0]
                start = current
                out.move(to: project(current))
            case .addLineToPoint:
                current = e.points[0]
                out.addLine(to: project(current))
            case .addQuadCurveToPoint:
                let (c, end) = (e.points[0], e.points[1])
                flatten([current, c, end], into: out)
                current = end
            case .addCurveToPoint:
                let (c1, c2, end) = (e.points[0], e.points[1], e.points[2])
                flatten([current, c1, c2, end], into: out)
                current = end
            case .closeSubpath:
                out.closeSubpath()
                current = start
            @unknown default:
                break
            }
        }
        return out
    }

    /// A Bézier curve (3 or 4 control points) as lines about 3 points long once projected.
    private func flatten(_ controls: [CGPoint], into out: CGMutablePath) {
        let projected = controls.map(project)
        let length = zip(projected, projected.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
        let n = min(max(Int(length / 3) + 1, 2), 64)
        for i in 1...n {
            let t = CGFloat(i) / CGFloat(n), s = 1 - t
            let p: CGPoint
            if controls.count == 3 {
                p = CGPoint(x: s * s * controls[0].x + 2 * s * t * controls[1].x + t * t * controls[2].x,
                            y: s * s * controls[0].y + 2 * s * t * controls[1].y + t * t * controls[2].y)
            } else {
                let (a, b, c, d) = (s * s * s, 3 * s * s * t, 3 * s * t * t, t * t * t)
                p = CGPoint(x: a * controls[0].x + b * controls[1].x + c * controls[2].x + d * controls[3].x,
                            y: a * controls[0].y + b * controls[1].y + c * controls[2].y + d * controls[3].y)
            }
            out.addLine(to: project(p))
        }
    }

    /// `p` relative to the turn's origin (across from the view's centre line, up from the focus row) and its scale.
    private func parts(_ p: CGPoint) -> (x: CGFloat, y: CGFloat, k: CGFloat) {
        let x = p.x - CGFloat(centreX) * plane.pitchRect.width, y = p.y - focusRow
        return (x, y, eye / (eye - y * sinTilt))
    }
}
