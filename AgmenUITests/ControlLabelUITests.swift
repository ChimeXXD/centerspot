import XCTest

/// SPEC §8 / D6-3: every control on every screen and sheet has a VoiceOver label in words: not empty, not its test
/// identifier and not an SF Symbol name ("xmark", "square.and.arrow.up"). Walks the library, the card menu, rename and
/// delete, the board (selection row, step actions, + Add, the title menu), the player sheet, the formation picker,
/// the step note, draw mode, playback and the export sheet in each of its states. Run with the AgmenUITests scheme.
final class ControlLabelUITests: XCTestCase {
    private typealias A = AccessibilityAudit
    private var problems: [String] = []
    private var screens: [String] = []

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEveryControlHasALabel() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetLibrary", "YES", "-exportFrameDelay", "40"]
        app.launch()

        // Library, its card menu, Rename and Delete.
        let example = A.card(app, "Overlap down the left, 5 steps")
        XCTAssertTrue(example.waitForExistence(timeout: A.timeout))
        audit(app, "library")
        example.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Rename"].waitForExistence(timeout: A.timeout))
        audit(app, "card menu")
        app.buttons["Rename"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: A.timeout))
        audit(app, "rename alert")
        app.alerts.buttons["Cancel"].tap()
        example.press(forDuration: 1.2)
        app.buttons["Delete"].tap()
        XCTAssertTrue(A.element(app, "library.delete.confirm").waitForExistence(timeout: A.timeout))
        audit(app, "delete dialog")
        // iOS 26+ shows the dialog as a popover with no Cancel button; tapping away dismisses it.
        A.dismissMenu(app)
        XCTAssertTrue(A.element(app, "library.delete.confirm").waitForNonExistence(timeout: A.timeout))

        // The board, a selected player, and a step's actions.
        example.tap()
        let three = A.element(app, "board.token.h3")
        XCTAssertTrue(three.waitForExistence(timeout: A.timeout))
        audit(app, "board")
        three.tap()
        XCTAssertTrue(A.element(app, "selection.edit").waitForExistence(timeout: A.timeout))
        audit(app, "selection row")
        let chip = A.element(app, "steps.chip.2")
        chip.tap()
        chip.tap()
        XCTAssertTrue(A.element(app, "step.duration").waitForExistence(timeout: A.timeout))
        audit(app, "step actions")
        let duration = A.element(app, "step.duration")
        let current = duration.label.replacingOccurrences(of: "Duration, ", with: "")
        duration.tap()
        audit(app, "duration menu")
        A.dismissMenu(app, keeping: current)
        XCTAssertEqual(duration.label, "Duration, \(current)", "closing the menu kept the duration")

        // Step note.
        A.element(app, "step.note").tap()
        XCTAssertTrue(A.element(app, "note.save").waitForExistence(timeout: A.timeout))
        audit(app, "step note")
        A.element(app, "note.close").tap()

        // Delete a step: the toast with Undo.
        chip.tap()
        if !A.element(app, "step.delete").exists { chip.tap() }
        A.element(app, "step.delete").tap()
        XCTAssertTrue(A.element(app, "toast.undo").waitForExistence(timeout: A.timeout))
        audit(app, "undo toast")
        A.element(app, "toast.undo").tap()

        // + Add and the title menu.
        A.element(app, "toolbar.add").tap()
        XCTAssertTrue(app.buttons["Our player"].waitForExistence(timeout: A.timeout))
        audit(app, "add menu")
        A.dismissMenu(app)
        A.element(app, "nav.title").tap()
        XCTAssertTrue(app.buttons["Rename"].waitForExistence(timeout: A.timeout))
        audit(app, "title menu")
        app.buttons["Rename"].tap()
        XCTAssertTrue(A.element(app, "rename.save").waitForExistence(timeout: A.timeout))
        audit(app, "board rename alert")
        app.alerts.buttons["Cancel"].tap()

        // Player sheet and its role line menu.
        three.doubleTap()
        XCTAssertTrue(A.element(app, "inspector.name").waitForExistence(timeout: A.timeout))
        audit(app, "player sheet")
        let roleLine = A.element(app, "inspector.role-line")
        let line = roleLine.label.replacingOccurrences(of: "Role line, ", with: "")
        roleLine.tap()
        audit(app, "role line menu")
        A.dismissMenu(app, keeping: line)
        A.element(app, "inspector.close").tap()

        // Formation picker.
        A.element(app, "toolbar.formation").tap()
        XCTAssertTrue(A.element(app, "formation.apply").waitForExistence(timeout: A.timeout))
        audit(app, "formation picker")
        A.element(app, "formation.close").tap()

        // Draw mode, and its mark tools on step 4, which has a zone, a line, rings and heat (D-65).
        A.element(app, "steps.chip.4").tap()
        A.element(app, "toolbar.draw").tap()
        XCTAssertTrue(A.element(app, "draw.done").waitForExistence(timeout: A.timeout))
        audit(app, "draw mode")
        for tool in ["line", "glow", "zone"] {
            A.element(app, "draw.kind.\(tool)").tap()
            audit(app, "draw \(tool)")
        }
        A.element(app, "draw.zone.1").tap()
        XCTAssertTrue(A.element(app, "draw.mark.remove").waitForExistence(timeout: A.timeout))
        audit(app, "zone selected")
        A.element(app, "draw.cancel").tap()

        // Playback.
        A.element(app, "toolbar.play").tap()
        XCTAssertTrue(A.element(app, "playback.toggle").waitForExistence(timeout: A.timeout))
        audit(app, "playback")
        A.element(app, "playback.done").tap()

        try walkExport(app)

        // A new tactic: the empty board.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        A.element(app, "launch.new").tap()
        XCTAssertTrue(A.element(app, "formation.close").waitForExistence(timeout: A.timeout))
        A.element(app, "formation.close").tap()
        XCTAssertTrue(A.element(app, "board.empty.pick").waitForExistence(timeout: A.timeout))
        audit(app, "empty board")

        XCTAssertEqual(screens.count, 27, "screens checked: \(screens)")
        XCTAssertTrue(problems.isEmpty, "\(problems.count) controls without a real label:\n" + problems.joined(separator: "\n"))
    }

    /// The export sheet: choosing (video and image), rendering, done and the error state. No Spotlight menu (D-66).
    @MainActor
    private func walkExport(_ app: XCUIApplication) throws {
        A.element(app, "toolbar.export").tap()
        let start = A.element(app, "export.start")
        XCTAssertTrue(start.waitForExistence(timeout: A.timeout))
        audit(app, "export")
        XCTAssertFalse(A.element(app, "export.spotlight").exists, "Spotlight is dropped (D-66)")
        start.tap()
        XCTAssertTrue(A.element(app, "export.cancel").waitForExistence(timeout: A.timeout))
        audit(app, "export rendering")
        A.element(app, "export.cancel").tap()
        A.element(app, "export.preset.image").tap()
        audit(app, "export image")
        start.tap()
        XCTAssertTrue(A.element(app, "export.done").waitForExistence(timeout: 60))
        audit(app, "export done")
        A.element(app, "export.close").tap()
        XCTAssertTrue(A.element(app, "toolbar.export").waitForExistence(timeout: A.timeout))
    }

    /// The error state needs its own launch (`-exportFails` fails the export at frame 10).
    @MainActor
    func testExportErrorHasLabels() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetLibrary", "YES", "-openExample", "YES", "-exportFails", "YES"]
        app.launch()
        XCTAssertTrue(A.element(app, "toolbar.export").waitForExistence(timeout: A.timeout))
        A.element(app, "toolbar.export").tap()
        A.element(app, "export.start").tap()
        XCTAssertTrue(A.element(app, "export.retry").waitForExistence(timeout: A.timeout))
        audit(app, "export error")
        XCTAssertTrue(problems.isEmpty, problems.joined(separator: "\n"))
    }

    @MainActor
    private func audit(_ app: XCUIApplication, _ screen: String) {
        sleep(1)  // let sheets and menus finish appearing
        screens.append(screen)
        problems += A.labelProblems(in: app, screen: screen)
        problems += A.descriptionIssues(in: app, screen: screen)
    }
}
