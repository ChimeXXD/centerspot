import XCTest

/// D-94 with real taps, on iPhone and iPad: Formation → Scenarios, nothing picked ("Pick a scenario" is off), pick
/// 3v2 counter, see it defending, set it up over the example's players (confirm first), and undo it from the toast.
/// Saves the mockup's frames (`formation--scenarios`, `-picked`, `-defending`, `board--scenario-applied`, on iPad
/// `ipad-formation--scenarios`) to `SHOTS_DIR`.
final class ScenarioUITests: XCTestCase {
    private typealias A = AccessibilityAudit

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testSetUpAScenarioThenUndoIt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetLibrary", "YES", "-openExample", "YES"]
        app.launch()
        XCTAssertTrue(A.element(app, "board.token.h9").waitForExistence(timeout: A.timeout))
        let pad = UIDevice.current.userInterfaceIdiom == .pad

        A.element(app, "toolbar.formation").tap()
        let scenarios = A.element(app, "formation.tab.scenarios")
        XCTAssertTrue(scenarios.waitForExistence(timeout: A.timeout))
        scenarios.tap()
        XCTAssertTrue(A.element(app, "scenario.side.attacking").isSelected)
        XCTAssertEqual(A.element(app, "scenario.shape").label, "Your shape, 4-3-3, 11-a-side. Change it")
        XCTAssertFalse(A.element(app, "formation.apply").isEnabled, "Pick a scenario until one is picked")
        XCTAssertTrue(A.element(app, "scenario.build-up").exists)
        sleep(1)
        A.save(pad ? "ipad-formation--scenarios" : "formation--scenarios", in: self)

        let counter = A.element(app, "scenario.3v2-counter")
        reveal(counter, in: app)
        counter.tap()
        XCTAssertTrue(counter.isSelected)
        XCTAssertEqual(A.element(app, "formation.apply").label, "Use 3v2 counter")
        sleep(1)
        A.save("formation--scenarios-picked", in: self)

        for _ in 0..<8 where !A.element(app, "scenario.side.defending").isHittable { app.swipeDown() }
        A.element(app, "scenario.side.defending").tap()
        XCTAssertTrue(A.element(app, "scenario.side.help").label.hasPrefix("They have the ball"))
        reveal(counter, in: app)
        sleep(1)
        A.save("formation--scenarios-defending", in: self)
        for _ in 0..<8 where !A.element(app, "scenario.side.attacking").isHittable { app.swipeDown() }
        A.element(app, "scenario.side.attacking").tap()

        A.element(app, "formation.apply").tap()
        let setUp = app.alerts.buttons["Set up"]
        XCTAssertTrue(setUp.waitForExistence(timeout: A.timeout), "a board with players asks first")
        setUp.tap()
        // The toast first: it only stays a few seconds.
        let toast = A.element(app, "toast.message")
        XCTAssertTrue(toast.waitForExistence(timeout: A.timeout))
        XCTAssertEqual(toast.label, "3v2 counter set up")
        A.save(pad ? "ipad-board--scenario-applied" : "board--scenario-applied", in: self)
        A.element(app, "toast.undo").tap()
        XCTAssertTrue(A.element(app, "board.token.h9").waitForExistence(timeout: A.timeout), "Undo brings the move back")
        XCTAssertTrue(A.element(app, "board.token.a7").exists)

        // Again, this time checking who is on the board.
        A.element(app, "toolbar.formation").tap()
        XCTAssertTrue(scenarios.waitForExistence(timeout: A.timeout))
        scenarios.tap()
        reveal(counter, in: app)
        counter.tap()
        A.element(app, "formation.apply").tap()
        XCTAssertTrue(setUp.waitForExistence(timeout: A.timeout))
        setUp.tap()

        // 10, 7 and 11 break on their 5 and 4 with their keeper back; everyone else has left the board.
        for id in ["h10", "h7", "h11", "a5", "a4", "a1", "ball"] {
            XCTAssertTrue(A.element(app, "board.token.\(id)").waitForExistence(timeout: A.timeout), id)
        }
        for id in ["h9", "h3", "a2", "a7"] { XCTAssertFalse(A.element(app, "board.token.\(id)").exists, id) }
        // D-96: the whole move, not just a position: the 3v2 counter's five steps replace the example's.
        // Steps show as chips (iPhone, iPad portrait) or rows (iPad landscape).
        XCTAssertTrue(A.element(app, "steps.chip.5").waitForExistence(timeout: A.timeout) || A.element(app, "steps.row.5").exists)
        XCTAssertFalse(A.element(app, "steps.chip.6").exists || A.element(app, "steps.row.6").exists)
    }

    /// Scrolls the sheet until `element` is wholly above the Use button (a tile under it would take the button's tap).
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let use = A.element(app, "formation.apply")
        for _ in 0..<10 where !(element.isHittable && element.frame.maxY < use.frame.minY - 4) {
            app.swipeUp(velocity: .slow)
        }
    }
}
