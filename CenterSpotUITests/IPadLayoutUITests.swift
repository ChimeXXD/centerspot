import XCTest

/// D-73 / D-75 on the iPad (run on the iPad Pro 13-inch simulator; skipped on iPhone). Landscape: the pitch fills the
/// height on the left and the right column lists every step with its note; tapping a row goes to that step; the draw
/// tools sit in the column. Portrait: the pitch is centred and as big as the height allows. Playback and Export still
/// open in both. Saves ipad-*.png to `SHOTS_DIR` (pass it as `TEST_RUNNER_SHOTS_DIR`).
final class IPadLayoutUITests: XCTestCase {
    private let timeout: TimeInterval = 15

    /// The example's steps as VoiceOver reads their rows (D-75).
    private let rows = [
        "Step 1 of 5, 1.2 seconds, 8 finds the winger",
        "Step 2 of 5, 1.4 seconds, 11 drives inside; 3 starts the overlap",
        "Step 3 of 5, 1.2 seconds, 11 slips it round the corner to 3; 9 attacks the box",
        "Step 4 of 5, 1.2 seconds, 3 crosses for 9",
        "Step 5 of 5, 1.2 seconds, 9 attacks the near post and finishes",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad layout only")
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    /// Chime's iPad and Mac (8 Nov): opening a tactic in landscape with the tips on crashed, because the steps
    /// list's rows read the tip state off the main thread. The tips are on here (the other tests hide them).
    /// The simulator never built the rows on SwiftUI's render thread, so this guards the flow, not the crash itself:
    /// that still needs the iPad.
    @MainActor
    func testLandscapeWithTipsOpensTheBoard() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-resetLibrary", "YES", "-onboarding", "YES"]
        app.launch()
        let skip = element(app, "onboarding.skip")
        XCTAssertTrue(skip.waitForExistence(timeout: timeout))
        skip.tap()
        let card = AccessibilityAudit.card(app, "Overlap down the left, 5 steps")
        XCTAssertTrue(card.waitForExistence(timeout: timeout))
        card.tap()
        XCTAssertTrue(element(app, "steps.row.2").waitForExistence(timeout: timeout), "the board opens")
        XCTAssertTrue(app.staticTexts["Move a player"].waitForExistence(timeout: timeout), "with its first tip")
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "and the app is still running")
    }

    @MainActor
    func testLandscape() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launchOnExample()
        let pitch = element(app, "board.pitch")
        XCTAssertGreaterThanOrEqual(pitch.frame.height, 800, "the pitch fills the height: \(pitch.frame)")

        // Every step as a row with its note (D-75); the chips are gone here.
        for (index, label) in rows.enumerated() {
            let row = element(app, "steps.row.\(index + 1)")
            XCTAssertTrue(row.waitForExistence(timeout: timeout), "row \(index + 1)")
            XCTAssertEqual(row.label, label)
            XCTAssertGreaterThan(row.frame.minX, pitch.frame.maxX, "the list sits right of the pitch")
        }
        XCTAssertFalse(element(app, "steps.chip.1").exists, "the list replaces the chips")
        XCTAssertTrue(element(app, "steps.row.1").isSelected)

        // Tap row 2: step 2 is on the board and lit.
        element(app, "steps.row.2").tap()
        XCTAssertTrue(pitch.waitForLabel("Pitch, step 2 of 5", timeout: timeout), pitch.label)
        XCTAssertTrue(element(app, "steps.row.2").isSelected)
        XCTAssertFalse(element(app, "steps.row.1").isSelected)

        // The mockup's frame: step 4, 3 selected.
        element(app, "steps.row.4").tap()
        XCTAssertTrue(pitch.waitForLabel("Pitch, step 4 of 5", timeout: timeout))
        // The ball sits on 3's lower right on step 4, so tap 3's upper left.
        element(app, "board.token.h3").coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.25)).tap()
        let edit = element(app, "selection.edit")
        XCTAssertTrue(edit.waitForExistence(timeout: timeout))
        XCTAssertGreaterThan(edit.frame.minX, pitch.frame.maxX, "the selected player row is in the column")
        XCTAssertTrue(element(app, "nav.share").exists)
        XCTAssertGreaterThan(element(app, "nav.title").frame.minX, pitch.frame.maxX, "the nav row tops the column")
        sleep(1)
        save("ipad-board-landscape")

        // Draw on step 2: the tools in the column, the toolbar stays with Draw lit and the rest disabled.
        element(app, "steps.row.2").tap()
        XCTAssertTrue(pitch.waitForLabel("Pitch, step 2 of 5", timeout: timeout))
        element(app, "toolbar.draw").tap()
        let run = element(app, "draw.kind.run")
        XCTAssertTrue(run.waitForExistence(timeout: timeout))
        XCTAssertGreaterThan(run.frame.minX, pitch.frame.maxX, "the draw tools are in the column")
        XCTAssertTrue(element(app, "draw.kind.glow").exists)
        XCTAssertTrue(element(app, "draw.title").exists)
        XCTAssertTrue(element(app, "steps.row.2").exists, "the steps stay in draw mode")
        XCTAssertTrue(element(app, "toolbar.draw").exists, "the toolbar stays")
        XCTAssertFalse(element(app, "toolbar.export").isEnabled, "the other tools are disabled")
        XCTAssertGreaterThanOrEqual(pitch.frame.height, 800, "the pitch keeps its size")
        sleep(1)
        save("ipad-draw-landscape")
        element(app, "draw.done").tap()
        XCTAssertTrue(element(app, "toolbar.export").waitForEnabled(timeout: timeout))

        try playAndExport(app, name: "landscape")
    }

    @MainActor
    func testPortrait() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launchOnExample()
        let pitch = element(app, "board.pitch")
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(pitch.frame.width, 700, "the pitch is big: \(pitch.frame)")
        XCTAssertEqual(pitch.frame.midX, window.midX, accuracy: 2, "the pitch is centred")
        XCTAssertEqual(pitch.frame.height / pitch.frame.width, 105.0 / 68.0, accuracy: 0.02, "the board hugs the pitch")

        // One row under the pitch: the chips on the left, the selection on the right.
        element(app, "steps.chip.4").tap()
        XCTAssertTrue(pitch.waitForLabel("Pitch, step 4 of 5", timeout: timeout))
        element(app, "board.token.h3").coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.25)).tap()
        let edit = element(app, "selection.edit")
        XCTAssertTrue(edit.waitForExistence(timeout: timeout))
        let chip = element(app, "steps.chip.1")
        XCTAssertEqual(edit.frame.midY, chip.frame.midY, accuracy: 4, "chips and actions share one row")
        XCTAssertGreaterThan(edit.frame.minX, chip.frame.maxX)
        XCTAssertGreaterThan(chip.frame.minY, pitch.frame.maxY, "the row is under the pitch")
        XCTAssertFalse(element(app, "steps.row.1").exists)
        sleep(1)
        save("ipad-board-portrait")

        try playAndExport(app, name: "portrait")
    }

    /// Playback opens and Done returns; the export sheet opens with its choices and closes.
    @MainActor
    private func playAndExport(_ app: XCUIApplication, name: String) throws {
        element(app, "toolbar.play").tap()
        let toggle = element(app, "playback.toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: timeout))
        toggle.tap()
        element(app, "playback.scrubber").coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.5)).tap()
        XCTAssertTrue(element(app, "playback.note").label.hasPrefix("Step 4 of 5"), element(app, "playback.note").label)
        if name == "landscape" {
            // D-92: the column lists every step while playing, the playing one lit; a tap plays from that step, and
            // there is no + (steps aren't edited mid-play).
            XCTAssertTrue(element(app, "steps.row.4").isSelected, "the playing step is lit")
            XCTAssertFalse(element(app, "steps.add").exists)
            element(app, "steps.row.2").tap()
            XCTAssertTrue(element(app, "playback.note").label.hasPrefix("Step 2 of 5"), element(app, "playback.note").label)
            XCTAssertTrue(element(app, "steps.row.2").isSelected)
            XCTAssertFalse(element(app, "steps.row.4").isSelected)
            element(app, "steps.row.4").tap()
        }
        sleep(1)
        save("ipad-playback-\(name)")
        element(app, "playback.done").tap()
        XCTAssertTrue(element(app, "toolbar.export").waitForExistence(timeout: timeout))

        element(app, "toolbar.export").tap()
        let start = element(app, "export.start")
        XCTAssertTrue(start.waitForExistence(timeout: timeout))
        XCTAssertTrue(element(app, "export.preview").exists)
        sleep(1)
        save("ipad-export-\(name)")
        element(app, "export.close").tap()
        XCTAssertTrue(start.waitForNonExistence(timeout: timeout))
    }

    @MainActor
    private func launchOnExample() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetLibrary", "YES", "-openExample", "YES"]
        app.launch()
        XCTAssertTrue(element(app, "board.token.h3").waitForExistence(timeout: timeout))
        sleep(1)  // let the rotation settle
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func save(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"] {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}

private extension XCUIElement {
    func waitForLabel(_ label: String, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
