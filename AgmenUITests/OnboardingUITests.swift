import XCTest

/// D-58, D-78 with real taps: the three welcome pages on first launch, Start opens the example move, then the five tips
/// one at a time, each done by doing what it says or closed with ×; Show tips again in the library's More menu brings
/// the welcome back, and Skip goes to the library. Saves the mockup's frames to `SHOTS_DIR` for comparison with
/// `.proof/design/`. Run with the AgmenUITests scheme.
final class OnboardingUITests: XCTestCase {
    private typealias A = AccessibilityAudit

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testWelcomeTipsAndShowTipsAgain() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetLibrary", "YES", "-onboarding", "YES"]
        app.launch()

        // The welcome, page by page.
        let titles = ["Draw the move, not just the shape", "Press Play. Watch it move", "Share it as a 9:16 clip"]
        XCTAssertTrue(app.staticTexts[titles[0]].waitForExistence(timeout: A.timeout))
        XCTAssertEqual(A.element(app, "onboarding.dots").label, "Page 1 of 3")
        sleep(1)
        A.save("onboarding-1--bc", in: self)
        for page in 2...3 {
            A.element(app, "onboarding.next").tap()
            XCTAssertTrue(app.staticTexts[titles[page - 1]].waitForExistence(timeout: A.timeout), "page \(page)")
            sleep(1)
            A.save("onboarding-\(page)--bc", in: self)
        }
        XCTAssertFalse(A.element(app, "onboarding.next").exists, "the last page starts instead")

        // Start: the example move, and the first tip at our 7 (D-82).
        A.element(app, "onboarding.start").tap()
        XCTAssertTrue(A.element(app, "board.token.h7").waitForExistence(timeout: A.timeout))
        XCTAssertTrue(app.staticTexts["Move a player"].waitForExistence(timeout: A.timeout))
        sleep(1)
        A.save("tip-drag--bc", in: self)

        // Done by doing it: dragging 7 brings the next tip.
        let seven = A.element(app, "board.token.h7").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        seven.press(forDuration: 0.2, thenDragTo: seven.withOffset(CGVector(dx: -30, dy: -20)))
        XCTAssertTrue(app.staticTexts["Move a player"].waitForNonExistence(timeout: A.timeout))
        XCTAssertTrue(app.staticTexts["Every step is a moment"].waitForExistence(timeout: A.timeout))
        sleep(1)
        A.save("tip-step--bc", in: self)

        // Closed with ×: the next one comes anyway.
        app.buttons["Close tip"].tap()
        XCTAssertTrue(app.staticTexts["Watch it move"].waitForExistence(timeout: A.timeout))
        XCTAssertTrue(app.staticTexts["Press Play to run the move. Pick Flat or Broadcast at the top."].exists)
        sleep(1)
        A.save("tip-play--bc", in: self)

        // Play: no tip while playing; after Done, Draw's.
        A.element(app, "toolbar.play").tap()
        XCTAssertTrue(A.element(app, "playback.done").waitForExistence(timeout: A.timeout))
        XCTAssertFalse(app.staticTexts["Draw a run"].exists, "no tip while playing")
        A.element(app, "playback.done").tap()
        XCTAssertTrue(app.staticTexts["Draw a run"].waitForExistence(timeout: A.timeout))
        sleep(1)
        A.save("tip-draw--bc", in: self)
        app.buttons["Close tip"].tap()
        XCTAssertTrue(app.staticTexts["Share the clip"].waitForExistence(timeout: A.timeout))
        sleep(1)
        A.save("tip-export--bc", in: self)
        A.element(app, "toolbar.export").tap()
        XCTAssertTrue(A.element(app, "export.start").waitForExistence(timeout: A.timeout))
        A.element(app, "export.close").tap()
        XCTAssertTrue(A.element(app, "toolbar.export").waitForExistence(timeout: A.timeout))
        XCTAssertFalse(app.staticTexts["Share the clip"].waitForExistence(timeout: 2), "all five are done")

        // Show tips again: the welcome comes back; Skip goes to the library.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(A.element(app, "library.more").waitForExistence(timeout: A.timeout))
        A.element(app, "library.more").tap()
        XCTAssertTrue(app.buttons["Show tips again"].waitForExistence(timeout: A.timeout))
        sleep(1)
        A.save("library--menu", in: self)
        app.buttons["Show tips again"].tap()
        XCTAssertTrue(app.staticTexts[titles[0]].waitForExistence(timeout: A.timeout))
        A.element(app, "onboarding.skip").tap()
        XCTAssertTrue(A.element(app, "launch.new").waitForExistence(timeout: A.timeout))
        // (The library's tagline is the welcome's first title, so check the welcome's own button is gone.)
        XCTAssertFalse(A.element(app, "onboarding.skip").exists)

        // The tips really are back, in order, on the next board opened (verifier, 8 Nov).
        A.card(app, "Overlap down the left, 5 steps").tap()
        XCTAssertTrue(app.staticTexts["Move a player"].waitForExistence(timeout: A.timeout))
        // No tip with a sheet open: the player sheet takes it away, and it comes back after.
        A.element(app, "board.token.h3").doubleTap()
        XCTAssertTrue(A.element(app, "inspector.name").waitForExistence(timeout: A.timeout))
        XCTAssertTrue(app.staticTexts["Move a player"].waitForNonExistence(timeout: A.timeout), "no tip over a sheet")
        A.element(app, "inspector.close").tap()
        XCTAssertTrue(app.staticTexts["Move a player"].waitForExistence(timeout: A.timeout))
        app.buttons["Close tip"].tap()
        XCTAssertTrue(app.staticTexts["Every step is a moment"].waitForExistence(timeout: A.timeout))
    }
}
