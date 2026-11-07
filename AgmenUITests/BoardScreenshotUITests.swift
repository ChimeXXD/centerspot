import XCTest

/// Walks the Day 3 screens with real taps and saves a screenshot of each to `SHOTS_DIR` (pass it as
/// `TEST_RUNNER_SHOTS_DIR`). Also checks a token's VoiceOver label (SPEC §8). Run with the AgmenUITests scheme.
final class BoardScreenshotUITests: XCTestCase {
    private let timeout: TimeInterval = 15

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testDay3Screens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-openExample", "YES"]
        app.launch()

        let new = newTacticButton(app)
        if !new.waitForExistence(timeout: timeout) {
            save("launch-missing")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        XCTAssertTrue(new.exists)
        sleep(2)  // the launch scene settles its layout after the first frame
        save("launch")
        let three = element(app, "board.token.h3")
        openNewTactic(app, until: three)
        XCTAssertTrue(three.waitForExistence(timeout: timeout))
        let nine = element(app, "board.token.h9")
        XCTAssertTrue(nine.label.hasPrefix("Number 9, striker, "), nine.label)
        XCTAssertTrue(nine.label.hasSuffix("step 1 of 5"), nine.label)
        XCTAssertTrue(element(app, "nav.share").exists, "Share sits in the nav bar (D-55)")
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
        // Back to the library first, or the next launch restores this document instead of the launch screen.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(newTacticButton(app).waitForExistence(timeout: timeout))
        app.terminate()

        // A blank tactic opens on the formation picker; closing it shows the empty board.
        let blank = XCUIApplication()
        blank.launch()
        XCTAssertTrue(newTacticButton(blank).waitForExistence(timeout: timeout))
        sleep(2)
        openNewTactic(blank, until: element(blank, "formation.apply"))
        XCTAssertTrue(element(blank, "formation.apply").waitForExistence(timeout: timeout))
        element(blank, "formation.close").tap()
        XCTAssertTrue(element(blank, "board.empty.pick").waitForExistence(timeout: timeout))
        sleep(1)
        save("board-empty")
    }

    /// The launch scene's New tactic button. The scene renders the button twice (a hidden toolbar copy carries the
    /// `launch.new` identifier), so find the visible one by its label.
    private func newTacticButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == 'New tactic' AND identifier != 'launch.new'")).firstMatch
    }

    /// Taps New tactic once it can be hit, then waits for `target`. One tap only: a second tap while the first
    /// document is still opening makes the system refuse both.
    private func openNewTactic(_ app: XCUIApplication, until target: XCUIElement) {
        let button = newTacticButton(app)
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: button)
        wait(for: [hittable], timeout: timeout)
        button.tap()
        _ = target.waitForExistence(timeout: 40)
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
