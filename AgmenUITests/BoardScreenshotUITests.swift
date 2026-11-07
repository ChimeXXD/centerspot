import XCTest

/// Walks the library (D-56) and the Day 3 screens with real taps and saves a screenshot of each to `SHOTS_DIR` (pass
/// it as `TEST_RUNNER_SHOTS_DIR`). Also checks VoiceOver labels (SPEC §8). Run with the AgmenUITests scheme.
final class BoardScreenshotUITests: XCTestCase {
    private let timeout: TimeInterval = 15

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLibraryAndBoard() throws {
        let app = XCUIApplication()
        // A clean library: the first launch adds the example move.
        app.launchArguments = ["-resetLibrary", "YES"]
        app.launch()

        let example = card(app, "Overlap down the left, 5 steps")
        XCTAssertTrue(example.waitForExistence(timeout: timeout), "the first launch adds the example")
        XCTAssertEqual(element(app, "library.card.1").label, "Overlap down the left, 5 steps")
        XCTAssertTrue(element(app, "launch.new").exists)
        sleep(1)
        save("library")

        // The hero move on the board.
        example.tap()
        let three = element(app, "board.token.h3")
        XCTAssertTrue(three.waitForExistence(timeout: timeout))
        let nine = element(app, "board.token.h9")
        XCTAssertTrue(nine.label.hasPrefix("Number 9, striker, "), nine.label)
        XCTAssertTrue(nine.label.hasSuffix("step 1 of 5"), nine.label)
        XCTAssertTrue(element(app, "nav.share").exists, "Share sits in the nav bar (D-55)")
        XCTAssertTrue(element(app, "nav.redo").exists, "a long title doesn't fold Redo away")
        XCTAssertEqual(element(app, "nav.title").label, "Overlap down the left")
        XCTAssertEqual(element(app, "board.formation-tag").label, "4-3-3")
        save("board")

        three.tap()
        XCTAssertTrue(element(app, "selection.edit").waitForExistence(timeout: timeout))
        save("board-selected")

        three.doubleTap()
        XCTAssertTrue(element(app, "inspector.name").waitForExistence(timeout: timeout))
        sleep(1)
        save("inspector")
        element(app, "inspector.close").tap()

        let chip = element(app, "steps.chip.3")
        XCTAssertTrue(chip.waitForExistence(timeout: timeout))
        chip.tap()
        chip.tap()
        XCTAssertTrue(element(app, "step.duration").waitForExistence(timeout: timeout))
        save("board-step-selected")

        element(app, "step.delete").tap()
        XCTAssertTrue(element(app, "toast.undo").waitForExistence(timeout: timeout))
        XCTAssertEqual(element(app, "board.step-label").label, "Step 2 of 4 · 1.4 s")
        save("board-undo-toast")
        element(app, "toast.undo").tap()
        XCTAssertTrue(element(app, "steps.chip.5").waitForExistence(timeout: timeout), "Undo brings the step back")
        XCTAssertEqual(element(app, "board.step-label").label, "Step 3 of 5 · 1.2 s", "and the board returns to it")

        element(app, "toolbar.formation").tap()
        XCTAssertTrue(element(app, "formation.apply").waitForExistence(timeout: timeout))
        sleep(1)
        save("formation")
        element(app, "formation.close").tap()
        goBack(app)
        XCTAssertTrue(example.waitForExistence(timeout: timeout), "back returns to the library")

        // New tactic opens a blank board on the formation picker; closing it shows the empty board.
        element(app, "launch.new").tap()
        XCTAssertTrue(element(app, "formation.apply").waitForExistence(timeout: timeout))
        element(app, "formation.close").tap()
        XCTAssertTrue(element(app, "board.empty.pick").waitForExistence(timeout: timeout))
        sleep(1)
        save("board-empty")

        // Rename from the board's title; the library shows the new name once the board closes.
        element(app, "nav.title").tap()
        let renameOnBoard = app.buttons["Rename"]
        XCTAssertTrue(renameOnBoard.waitForExistence(timeout: timeout))
        renameOnBoard.tap()
        // An alert drops a text field's identifier, so find it in the alert.
        let boardField = app.alerts.textFields.firstMatch
        XCTAssertTrue(boardField.waitForExistence(timeout: timeout))
        boardField.tap()
        boardField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20) + "Low block")
        element(app, "rename.save").tap()
        XCTAssertTrue(app.descendants(matching: .any)["nav.title"].waitForExistence(timeout: timeout))
        XCTAssertEqual(element(app, "nav.title").label, "Low block")
        XCTAssertTrue(element(app, "nav.undo").isEnabled, "the rename can be undone")
        goBack(app)
        let blank = card(app, "Low block, 1 step")
        XCTAssertTrue(blank.waitForExistence(timeout: timeout), "the new tactic shows in the library, renamed")
        XCTAssertTrue(example.exists)

        // Rename from the context menu.
        blank.press(forDuration: 1.2)
        let rename = app.buttons["Rename"]
        XCTAssertTrue(rename.waitForExistence(timeout: timeout))
        save("library-menu")
        rename.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20) + "Back three")
        element(app, "library.rename.save").tap()
        let renamed = card(app, "Back three, 1 step")
        XCTAssertTrue(renamed.waitForExistence(timeout: timeout), "rename shows the new title")
        XCTAssertFalse(blank.exists)

        // Delete asks first.
        renamed.press(forDuration: 1.2)
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: timeout))
        delete.tap()
        let confirm = element(app, "library.delete.confirm")
        XCTAssertTrue(confirm.waitForExistence(timeout: timeout), "Delete asks first")
        XCTAssertTrue(app.staticTexts["Delete “Back three”?"].exists)
        XCTAssertTrue(app.staticTexts["This can't be undone."].exists)
        XCTAssertTrue(renamed.exists, "nothing is deleted before the answer")
        sleep(1)
        save("library-delete")
        confirm.tap()
        XCTAssertTrue(renamed.waitForNonExistence(timeout: timeout), "the card is gone")
        XCTAssertTrue(example.exists)
        sleep(1)
        save("library-after")
    }

    /// Day 4: Play the hero move (the scrubber replaces the strip, Pause, Done returns to the step), then draw a finger
    /// run from a player on the last step (D-28 adds step 6), Done keeps it, Undo takes it away, Cancel leaves nothing.
    @MainActor
    func testPlaybackAndDraw() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetLibrary", "YES"]
        app.launch()
        let example = card(app, "Overlap down the left, 5 steps")
        XCTAssertTrue(example.waitForExistence(timeout: timeout))
        example.tap()
        XCTAssertTrue(element(app, "board.token.h3").waitForExistence(timeout: timeout))

        // Playback: the scrubber replaces the steps strip and the toolbar.
        element(app, "toolbar.play").tap()
        let toggle = element(app, "playback.toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: timeout))
        XCTAssertEqual(toggle.label, "Pause")
        XCTAssertFalse(element(app, "steps.chip.1").exists, "the scrubber replaces the strip")
        XCTAssertFalse(element(app, "toolbar.play").exists)
        toggle.tap()
        XCTAssertEqual(toggle.label, "Play")

        // Scrub into step 4's segment (3.1 of 5 equal segments: its hold, about 4.85 s).
        let scrubber = element(app, "playback.scrubber")
        scrubber.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.5)).tap()
        XCTAssertTrue(element(app, "playback.note").label.hasPrefix("Step 4 of 5 · 3 crosses for 9"), element(app, "playback.note").label)
        XCTAssertTrue(element(app, "playback.time").label.hasPrefix("0:04."), element(app, "playback.time").label)
        XCTAssertTrue(element(app, "playback.time").label.hasSuffix(" / 0:06.5"), "the timeline's length, not the export's")
        XCTAssertEqual(scrubber.label, "Step 4 of 5")

        // Mid-move while playing, as in the mockup (step 4's move runs 5.0…6.2 s).
        toggle.tap()
        XCTAssertEqual(toggle.label, "Pause")
        usleep(600_000)
        save("playback")
        toggle.tap()
        scrubber.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.5)).tap()
        element(app, "playback.done").tap()
        XCTAssertTrue(element(app, "steps.chip.1").waitForExistence(timeout: timeout))
        XCTAssertEqual(element(app, "board.step-label").label, "Step 4 of 5 · 1.2 s", "Done returns to the step it stopped on")

        // Draw: a finger run from 3 on the last step adds step 6 (D-28).
        element(app, "steps.chip.5").tap()
        element(app, "toolbar.draw").tap()
        XCTAssertTrue(element(app, "draw.title").waitForExistence(timeout: timeout))
        XCTAssertTrue(element(app, "draw.kind.run").isSelected, "Run is picked")
        XCTAssertEqual(element(app, "draw.hint").label, "Start on a player to draw their run.")
        XCTAssertEqual(element(app, "draw.kind-help").label, "Run · solid line · the player follows it")
        XCTAssertFalse(element(app, "steps.chip.1").exists)
        let pitch = element(app, "board.pitch")
        XCTAssertEqual(pitch.label, "Pitch, step 5 of 5")
        drawStroke(from: element(app, "board.token.h3"))
        XCTAssertTrue(pitch.waitForLabel("Pitch, step 5 of 6", timeout: timeout), "the run added a step: \(pitch.label)")
        sleep(1)
        save("draw")
        element(app, "draw.done").tap()
        XCTAssertTrue(element(app, "steps.chip.6").waitForExistence(timeout: timeout), "the strip shows the new step")
        XCTAssertEqual(element(app, "board.step-label").label, "Step 5 of 6 · 1.2 s")

        // Undo removes the drawn run and its step.
        element(app, "nav.undo").tap()
        XCTAssertTrue(element(app, "steps.chip.6").waitForNonExistence(timeout: timeout), "Undo takes the run back")
        XCTAssertEqual(element(app, "board.step-label").label, "Step 5 of 5 · 1.2 s")

        // Cancel leaves without changes.
        element(app, "toolbar.draw").tap()
        XCTAssertTrue(element(app, "draw.cancel").waitForExistence(timeout: timeout))
        element(app, "draw.kind.pass").tap()
        XCTAssertEqual(element(app, "draw.kind-help").label, "Pass · dashed line · the ball follows it")
        // 3 doesn't have the ball on step 5, so a pass would only draw an arrow; a press moves 3.
        element(app, "draw.kind.press").tap()
        drawStroke(from: element(app, "board.token.h3"))
        XCTAssertTrue(pitch.waitForLabel("Pitch, step 5 of 6", timeout: timeout))
        element(app, "draw.cancel").tap()
        XCTAssertTrue(element(app, "steps.chip.5").waitForExistence(timeout: timeout))
        XCTAssertFalse(element(app, "steps.chip.6").exists, "Cancel took the stroke back")
    }

    /// A finger stroke up and inside from a token, pressed first so it starts on the token.
    private func drawStroke(from token: XCUIElement) {
        let start = token.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: start.withOffset(CGVector(dx: 80, dy: -60)))
    }

    /// A library card by its VoiceOver label ("<title>, N steps").
    private func card(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'library.card.' AND label == %@", label)).firstMatch
    }

    private func goBack(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
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
    /// Waits for the element's label to become `label`.
    func waitForLabel(_ label: String, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
