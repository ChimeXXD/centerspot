import XCTest

/// BR-2 (D-66, D-76) with real taps: Play shows the Flat | Broadcast switch where Back was; Broadcast moves the players
/// to where the tilted camera draws them; the choice is remembered across playback and launches; editing stays flat.
/// Saves `playback--broadcast-3d` to `SHOTS_DIR`. Run with the AgmenUITests scheme.
final class CameraUITests: XCTestCase {
    private typealias A = AccessibilityAudit

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCameraSwitchIsRememberedAndEditingStaysFlat() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetLibrary", "YES"]
        app.launch()
        openExample(app)
        let editing = A.element(app, "board.token.h9").frame

        play(app)
        XCTAssertFalse(app.navigationBars.buttons["BackButton"].exists, "the switch stands where Back was")
        A.element(app, "playback.camera.broadcast").tap()
        XCTAssertTrue(A.element(app, "playback.camera.broadcast").isSelected)
        XCTAssertFalse(A.element(app, "playback.camera.flat").isSelected)
        let tilted = A.element(app, "board.token.h9").frame
        A.element(app, "playback.camera.flat").tap()
        XCTAssertTrue(A.element(app, "playback.camera.flat").isSelected)
        let flat = A.element(app, "board.token.h9").frame
        XCTAssertGreaterThan(distance(tilted, flat), 20, "the camera moves 9: \(tilted) vs \(flat)")

        // Done: editing is flat, whatever the camera.
        A.element(app, "playback.camera.broadcast").tap()
        A.element(app, "playback.done").tap()
        XCTAssertTrue(A.element(app, "steps.chip.1").waitForExistence(timeout: A.timeout))
        A.element(app, "steps.chip.1").tap()
        XCTAssertLessThan(distance(A.element(app, "board.token.h9").frame, editing), 2, "editing stays flat")

        // Remembered: Flat picked here is still Flat after a relaunch.
        play(app)
        XCTAssertTrue(A.element(app, "playback.camera.broadcast").isSelected, "remembered within the session")
        A.element(app, "playback.camera.flat").tap()
        app.terminate()
        app.launchArguments = []
        app.launch()
        openExample(app)
        play(app)
        XCTAssertTrue(A.element(app, "playback.camera.flat").isSelected, "remembered after a relaunch")

        // Back to Broadcast (the default) for the mockup's frame: step 4, paused.
        A.element(app, "playback.camera.broadcast").tap()
        A.element(app, "playback.scrubber").coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)).tap()
        XCTAssertTrue(A.element(app, "playback.note").label.hasPrefix("Step 4 of 5"), A.element(app, "playback.note").label)
        sleep(1)
        A.save("playback--broadcast-3d", in: self)
    }

    @MainActor
    private func openExample(_ app: XCUIApplication) {
        let example = A.card(app, "Overlap down the left, 5 steps")
        XCTAssertTrue(example.waitForExistence(timeout: A.timeout))
        example.tap()
        XCTAssertTrue(A.element(app, "board.token.h9").waitForExistence(timeout: A.timeout))
    }

    /// Play, then pause at once, so frames compare at one instant.
    @MainActor
    private func play(_ app: XCUIApplication) {
        A.element(app, "toolbar.play").tap()
        let toggle = A.element(app, "playback.toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: A.timeout))
        toggle.tap()
        A.element(app, "playback.scrubber").coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)).tap()
    }

    private func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        hypot(a.midX - b.midX, a.midY - b.midY)
    }
}
