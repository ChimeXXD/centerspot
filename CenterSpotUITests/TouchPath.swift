import XCTest

/// One finger along a path of screen points, for strokes XCUICoordinate can't draw (its drags are straight lines).
/// XCTest has no public API for this, so it uses the runtime's `XCPointerEventPath` and `XCSynthesizedEventRecord`,
/// the same machinery XCUICoordinate drags are built on. Test-only; never in the app.
@MainActor
enum TouchPath {
    /// The runtime this relies on isn't there (a new Xcode): the test fails, saying what's missing.
    struct Missing: Error, CustomStringConvertible {
        let name: String
        var description: String { "event synthesis: no \(name)" }
    }

    private typealias InitPath = @convention(c) (UnsafeRawPointer, Selector, CGPoint, Double) -> UnsafeRawPointer?
    private typealias Move = @convention(c) (UnsafeRawPointer, Selector, CGPoint, Double) -> Void
    private typealias Lift = @convention(c) (UnsafeRawPointer, Selector, Double) -> Void
    private typealias InitRecord = @convention(c) (UnsafeRawPointer, Selector, UnsafeRawPointer, Int) -> UnsafeRawPointer?
    private typealias Add = @convention(c) (UnsafeRawPointer, Selector, UnsafeRawPointer) -> Void
    private typealias Synthesize = @convention(c) (UnsafeRawPointer, Selector, UnsafeMutableRawPointer?) -> Bool

    /// Presses at the first point, holds `hold` seconds, moves through the rest `step` seconds apart, then lifts.
    static func drag(through points: [CGPoint], hold: Double = 0.2, step: Double = 0.03) throws {
        guard let start = points.first,
              let pathClass = NSClassFromString("XCPointerEventPath"),
              let recordClass = NSClassFromString("XCSynthesizedEventRecord") else {
            throw Missing(name: "XCPointerEventPath")
        }
        let path = try make(pathClass, "initForTouchAtPoint:offset:") { (imp: InitPath, raw, sel) in imp(raw, sel, start, 0) }
        var offset = hold
        for point in points.dropFirst() {
            offset += step
            try call(path, "moveToPoint:atOffset:") { (imp: Move, raw, sel) in imp(raw, sel, point, offset) }
        }
        try call(path, "liftUpAtOffset:") { (imp: Lift, raw, sel) in imp(raw, sel, offset + step) }

        let name = "CenterSpot stroke" as NSString
        let record = try withExtendedLifetime(name) {
            try make(recordClass, "initWithName:interfaceOrientation:") { (imp: InitRecord, raw, sel) in
                imp(raw, sel, Unmanaged.passUnretained(name).toOpaque(), UIInterfaceOrientation.portrait.rawValue)
            }
        }
        try call(record, "addPointerEventPath:") { (imp: Add, raw, sel) in
            imp(raw, sel, Unmanaged.passUnretained(path).toOpaque())
        }
        let synthesized = try call(record, "synthesizeWithError:") { (imp: Synthesize, raw, sel) in imp(raw, sel, nil) }
        XCTAssertTrue(synthesized, "the stroke was synthesized")
        withExtendedLifetime(path) {}
    }

    /// `alloc` then the init `selector` (which consumes the allocation and returns +1), as ARC would.
    private static func make<F>(_ cls: AnyClass, _ selector: String,
                                _ body: (F, UnsafeRawPointer, Selector) -> UnsafeRawPointer?) throws -> AnyObject {
        let sel = NSSelectorFromString(selector)
        guard let method = class_getInstanceMethod(cls, sel),
              let allocated = (cls as AnyObject).perform(NSSelectorFromString("alloc")) else {
            throw Missing(name: selector)
        }
        let imp = unsafeBitCast(method_getImplementation(method), to: F.self)
        guard let made = body(imp, UnsafeRawPointer(allocated.toOpaque()), sel) else {
            throw Missing(name: "\(selector) (returned nil)")
        }
        return Unmanaged<AnyObject>.fromOpaque(made).takeRetainedValue()
    }

    @discardableResult
    private static func call<F, R>(_ object: AnyObject, _ selector: String,
                                   _ body: (F, UnsafeRawPointer, Selector) -> R) throws -> R {
        let sel = NSSelectorFromString(selector)
        guard let method = class_getInstanceMethod(type(of: object), sel) else { throw Missing(name: selector) }
        let imp = unsafeBitCast(method_getImplementation(method), to: F.self)
        return withExtendedLifetime(object) { body(imp, UnsafeRawPointer(Unmanaged.passUnretained(object).toOpaque()), sel) }
    }
}
