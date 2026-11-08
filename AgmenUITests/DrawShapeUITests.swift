import XCTest

/// D-72 with real touches (mockup draw--shape-straight, draw--shape-curved, ipad-draw--landscape): Straight is the
/// default and draws no dot; Curved draws one bend with a middle dot; dragging the dot re-bends it in one undo step;
/// tapping the arrow again shows the dot. Saves the frames to `SHOTS_DIR` for comparison with the mockup. Run with the
/// AgmenUITests scheme.
final class DrawShapeUITests: XCTestCase {
    private typealias A = AccessibilityAudit

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testStraightThenCurvedThenBend() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "iPhone flow: on iPad the finger doesn't draw")
        let app = openStepTwo()
        A.element(app, "toolbar.draw").tap()
        let straight = A.element(app, "draw.shape.straight"), curved = A.element(app, "draw.shape.curved")
        XCTAssertTrue(straight.waitForExistence(timeout: A.timeout))
        XCTAssertTrue(straight.isSelected, "Straight is the default")
        XCTAssertFalse(curved.isSelected)
        XCTAssertEqual(A.element(app, "draw.shape-label").label, "Shape")
        XCTAssertFalse(A.element(app, "draw.kind-help").exists, "the Shape row takes the help line's place for arrows")

        // Straight: the run joins where the stroke starts and ends; no dot.
        let three = A.element(app, "board.token.h3")
        try TouchPath.drag(through: run(from: three, in: app))
        XCTAssertTrue(A.element(app, "draw.hint").waitForLabel("The run goes straight to where you lift.", timeout: A.timeout),
                      A.element(app, "draw.hint").label)
        let handle = A.element(app, "draw.bend.handle")
        XCTAssertFalse(handle.exists, "a straight arrow has no dot")
        sleep(1)
        A.save("draw--shape-straight", in: self)

        // Curved: the redrawn run bends through the stroke's deepest point, and its dot shows.
        curved.tap()
        XCTAssertTrue(curved.isSelected)
        XCTAssertTrue(straight.exists && !straight.isSelected)
        try TouchPath.drag(through: run(from: three, in: app))
        XCTAssertTrue(handle.waitForExistence(timeout: A.timeout), "the curved arrow is selected, with its dot")
        XCTAssertEqual(handle.label, "Bend of 3's run. Drag to change the curve.")
        XCTAssertEqual(A.element(app, "draw.hint").label, "Drag the middle dot to change the bend.")
        sleep(1)
        A.save("draw--shape-curved", in: self)

        // Drag the dot out: the bend follows, committed on lift.
        let before = handle.frame
        let grab = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grab.press(forDuration: 0.2, thenDragTo: grab.withOffset(CGVector(dx: 60, dy: 0)))
        XCTAssertTrue(handle.waitForExistence(timeout: A.timeout))
        XCTAssertGreaterThan(handle.frame.midX - before.midX, 30, "the dot moved with the finger: \(before) → \(handle.frame)")

        // Done, then one Undo takes the bend back (the curved run stays): tapping the arrow shows the dot where it was.
        A.element(app, "draw.done").tap()
        XCTAssertTrue(A.element(app, "nav.undo").waitForExistence(timeout: A.timeout))
        A.element(app, "nav.undo").tap()
        A.element(app, "toolbar.draw").tap()
        XCTAssertTrue(curved.waitForExistence(timeout: A.timeout))
        XCTAssertTrue(curved.isSelected, "the shape is remembered while the board is open")
        XCTAssertFalse(handle.exists, "nothing is selected when Draw opens")
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: before.midX, dy: before.midY)).tap()
        XCTAssertTrue(handle.waitForExistence(timeout: A.timeout), "tapping the curved arrow selects it")
        XCTAssertLessThan(abs(handle.frame.midX - before.midX), 2, "Undo put the bend back: \(before) → \(handle.frame)")
        XCTAssertLessThan(abs(handle.frame.midY - before.midY), 2)

        // Dragged onto the straight line, the arrow straightens and its dot goes.
        let line = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let chordMid = chordMiddle(from: three, in: app)
        line.press(forDuration: 0.2, thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(chordMid))
        XCTAssertTrue(handle.waitForNonExistence(timeout: A.timeout), "a straight arrow has no dot")

        // Back to Straight: the next run has no dot.
        straight.tap()
        try TouchPath.drag(through: run(from: A.element(app, "board.token.h7"), in: app))
        XCTAssertFalse(handle.exists)
        A.element(app, "draw.cancel").tap()
    }

    /// iPad landscape (D-73): the Shape row sits in the column's tools card and hides for the mark tools.
    @MainActor
    func testShapeRowInTheIPadColumn() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad column")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = openStepTwo()
        A.element(app, "toolbar.draw").tap()
        let curved = A.element(app, "draw.shape.curved")
        XCTAssertTrue(curved.waitForExistence(timeout: A.timeout))
        curved.tap()
        XCTAssertTrue(curved.isSelected)
        sleep(1)
        A.save("ipad-draw--landscape", in: self)
        A.element(app, "draw.kind.zone").tap()
        XCTAssertTrue(A.element(app, "draw.kind-help").waitForExistence(timeout: A.timeout))
        XCTAssertFalse(curved.exists, "marks keep their help line; no Shape row")
        A.element(app, "draw.kind.run").tap()
        XCTAssertTrue(curved.waitForExistence(timeout: A.timeout))
        XCTAssertTrue(curved.isSelected, "the shape is kept while Draw is open")
        A.element(app, "draw.cancel").tap()
    }

    // MARK: Helpers

    @MainActor
    private func openStepTwo() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetLibrary", "YES"]
        app.launch()
        let example = A.card(app, "Overlap down the left, 5 steps")
        XCTAssertTrue(example.waitForExistence(timeout: A.timeout))
        example.tap()
        XCTAssertTrue(A.element(app, "board.token.h3").waitForExistence(timeout: A.timeout))
        let chip = A.element(app, "steps.chip.2")
        (chip.exists ? chip : A.element(app, "steps.row.2")).tap()
        return app
    }

    /// The mockup's RUN3 (from 3 up the left, bowed toward the touchline), as a finger stroke in screen points: 30
    /// points along the quadratic through its middle point.
    @MainActor
    private func run(from token: XCUIElement, in app: XCUIApplication) -> [CGPoint] {
        let s = CGPoint(x: token.frame.midX, y: token.frame.midY)
        let (mid, end) = runShape(in: app)
        let m = CGPoint(x: s.x + mid.dx, y: s.y + mid.dy), e = CGPoint(x: s.x + end.dx, y: s.y + end.dy)
        let c = CGPoint(x: 2 * m.x - (s.x + e.x) / 2, y: 2 * m.y - (s.y + e.y) / 2)
        return (0...30).map { i in
            let t = CGFloat(i) / 30, u = 1 - t
            return CGPoint(x: u * u * s.x + 2 * u * t * c.x + t * t * e.x, y: u * u * s.y + 2 * u * t * c.y + t * t * e.y)
        }
    }

    /// Half way between the run's ends, where the straight line passes.
    @MainActor
    private func chordMiddle(from token: XCUIElement, in app: XCUIApplication) -> CGVector {
        let (_, end) = runShape(in: app)
        return CGVector(dx: token.frame.midX + end.dx / 2, dy: token.frame.midY + end.dy / 2)
    }

    /// RUN3's middle and end from its start, in screen points: (−0.10, +0.17) and (−0.08, +0.34) of the pitch.
    @MainActor
    private func runShape(in app: XCUIApplication) -> (mid: CGVector, end: CGVector) {
        let w = A.element(app, "board.pitch").frame.width, l = w * 105 / 68
        return (CGVector(dx: -0.10 * w, dy: -0.17 * l), CGVector(dx: -0.08 * w, dy: -0.34 * l))
    }
}

private extension XCUIElement {
    func waitForLabel(_ label: String, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
