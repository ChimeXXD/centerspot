import XCTest

/// SPEC §8 / D6-3: every sheet at the largest accessibility text size (AX5). Saves ax5-*.png of the library, the board,
/// the player sheet, the formation picker, the step note, the export sheet (choosing, rendering, done), the rename
/// alert, draw mode and playback, for review. Checks that each sheet's main action can still be reached.
final class DynamicTypeUITests: XCTestCase {
    private typealias A = AccessibilityAudit

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEverySheetAtAX5() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetLibrary", "YES", "-exportFrameDelay", "40",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        let example = A.card(app, "Overlap down the left, 5 steps")
        XCTAssertTrue(example.waitForExistence(timeout: A.timeout))
        shoot("library")
        app.swipeUp()
        shoot("library-scrolled")
        reach(example, in: app)

        example.press(forDuration: 1.2)
        let rename = app.buttons["Rename"]
        XCTAssertTrue(rename.waitForExistence(timeout: A.timeout))
        rename.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: A.timeout))
        shoot("rename-alert")
        XCTAssertTrue(app.alerts.buttons["Cancel"].isHittable, "Cancel is reachable in the rename alert")
        app.alerts.buttons["Cancel"].tap()

        reach(example, in: app)
        example.tap()
        let three = A.element(app, "board.token.h3")
        XCTAssertTrue(three.waitForExistence(timeout: A.timeout))
        shoot("board")
        three.tap()
        XCTAssertTrue(A.element(app, "selection.edit").waitForExistence(timeout: A.timeout))
        shoot("board-selected")

        // Player sheet: scroll to Delete player.
        three.doubleTap()
        XCTAssertTrue(A.element(app, "inspector.name").waitForExistence(timeout: A.timeout))
        shoot("player-sheet")
        reach(A.element(app, "inspector.delete"), in: app)
        shoot("player-sheet-end")
        A.element(app, "inspector.close").tap()

        // Step note and the step actions row.
        let chip = A.element(app, "steps.chip.2")
        chip.tap()
        chip.tap()
        XCTAssertTrue(A.element(app, "step.note").waitForExistence(timeout: A.timeout))
        shoot("step-actions")
        A.element(app, "step.note").tap()
        XCTAssertTrue(A.element(app, "note.save").waitForExistence(timeout: A.timeout))
        shoot("step-note")
        XCTAssertTrue(A.element(app, "note.save").isHittable, "Save note is reachable with the keyboard up")
        A.element(app, "note.close").tap()

        // Formation picker: the Use button stays pinned under the grid.
        A.element(app, "toolbar.formation").tap()
        XCTAssertTrue(A.element(app, "formation.apply").waitForExistence(timeout: A.timeout))
        shoot("formation")
        XCTAssertTrue(A.element(app, "formation.apply").isHittable, "Use stays in reach")
        A.element(app, "formation.close").tap()

        // Draw mode and playback.
        A.element(app, "toolbar.draw").tap()
        XCTAssertTrue(A.element(app, "draw.done").waitForExistence(timeout: A.timeout))
        shoot("draw")
        XCTAssertTrue(A.element(app, "draw.kind.press").isHittable, "every draw kind is reachable")
        A.element(app, "draw.cancel").tap()
        A.element(app, "toolbar.play").tap()
        XCTAssertTrue(A.element(app, "playback.toggle").waitForExistence(timeout: A.timeout))
        A.element(app, "playback.toggle").tap()  // pause, so the screenshot is still
        shoot("playback")
        XCTAssertTrue(A.element(app, "playback.next").isHittable, "Next step is reachable")
        A.element(app, "playback.done").tap()

        try exportStates(app)
    }

    /// The export sheet: choosing, scrolled to Export, rendering, and done with Share and Save to Photos.
    @MainActor
    private func exportStates(_ app: XCUIApplication) throws {
        A.element(app, "toolbar.export").tap()
        let start = A.element(app, "export.start")
        XCTAssertTrue(start.waitForExistence(timeout: A.timeout))
        shoot("export")
        reach(start, in: app)
        shoot("export-scrolled")
        start.tap()
        let cancel = A.element(app, "export.cancel")
        XCTAssertTrue(cancel.waitForExistence(timeout: A.timeout))
        reach(cancel, in: app)
        shoot("export-rendering")
        cancel.tap()
        reach(A.element(app, "export.preset.image"), in: app)
        A.element(app, "export.preset.image").tap()
        reach(start, in: app)
        start.tap()
        XCTAssertTrue(A.element(app, "export.done").waitForExistence(timeout: 60))
        shoot("export-done")
        reach(A.element(app, "export.save"), in: app)
        shoot("export-done-scrolled")
    }

    /// Scrolls up until `element` can be tapped; fails if it never comes into reach.
    @MainActor
    private func reach(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: A.timeout), "\(element) exists", file: file, line: line)
        var tries = 0
        while !element.isHittable, tries < 6 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(element.isHittable, "\(element.identifier) can be reached by scrolling", file: file, line: line)
    }

    @MainActor
    private func shoot(_ name: String) {
        sleep(1)
        A.save("ax5-\(name)", in: self)
    }
}
