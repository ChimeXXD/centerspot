import XCTest

/// D-89 with a full library (`-seedLibrary N` adds N tactics after the example): on an iPhone the last move plays at
/// the top, then tall cards two a row, with New tactic floating at the bottom; on an iPad a sidebar (New tactic, the
/// filters) and as many tall cards a row as fit, 5 in landscape on the 13-inch. Saves library-*.png to `SHOTS_DIR`
/// (pass it as `TEST_RUNNER_SHOTS_DIR`).
final class LibraryGridUITests: XCTestCase {
    private typealias A = AccessibilityAudit

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testPhoneLeadsWithTheLastMoveThenTwoTallCardsARow() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "iPhone layout")
        let app = launchSeeded(12)
        let window = app.windows.firstMatch.frame
        let resume = A.element(app, "library.resume"), new = A.element(app, "launch.new")
        XCTAssertTrue(resume.exists, "the last move plays at the top")
        XCTAssertEqual(resume.label, "Latest: Overlap down the left", "nothing opened yet: the newest")
        XCTAssertTrue(window.contains(new.frame), "New tactic is on screen: \(new.frame)")
        XCTAssertGreaterThan(new.frame.minY, window.height * 0.8, "New tactic floats at the bottom: \(new.frame)")

        let cards = (1...4).map { A.element(app, "library.card.\($0)") }
        XCTAssertGreaterThan(cards[0].frame.minY, resume.frame.maxY, "the cards come after the last move")
        XCTAssertEqual(cards[0].frame.minY, cards[1].frame.minY, accuracy: 0.5, "two a row")
        XCTAssertLessThan(cards[0].frame.maxX, cards[1].frame.minX, "left to right")
        XCTAssertGreaterThan(cards[2].frame.minY, cards[0].frame.maxY, "the third starts the next row")
        XCTAssertGreaterThan(cards[0].frame.height, cards[0].frame.width, "tall, like the 9:16 video: \(cards[0].frame)")
        XCTAssertEqual(cards[0].label, "Overlap down the left, 5 steps", "the example stays first, with its label")
        XCTAssertTrue((cards[0].value as? String)?.hasSuffix(", edited today") == true, "\(String(describing: cards[0].value))")
        A.save("library-phone", in: self)

        // The press-and-hold menu is still there.
        cards[1].press(forDuration: 1.2)
        for action in ["Rename", "Duplicate", "Share", "Delete"] {
            XCTAssertTrue(app.buttons[action].waitForExistence(timeout: A.timeout), action)
        }
        A.save("library-phone-menu", in: self)
    }

    @MainActor
    func testIPadLandscapeHasTheSidebarAndFiveARow() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad layout")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launchSeeded(22)
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.width, window.height, "landscape")
        // 5 from 1300 pt (the 13-inch's 1376); the 11-inch (1210 pt) fits 4 beside the sidebar.
        XCTAssertEqual(cardsInFirstRow(app), window.width >= 1300 ? 5 : 4, "cards in the first row at \(window.width) pt")

        let new = A.element(app, "launch.new").frame, all = A.element(app, "library.filter.all")
        XCTAssertLessThan(new.maxX, 300, "New tactic sits in the sidebar: \(new)")
        XCTAssertTrue(all.isSelected, "All moves is the current filter")
        XCTAssertTrue(A.element(app, "library.resume.export").exists, "Export video beside the last move")
        A.save("library-ipad-landscape", in: self)

        // Every seeded move was edited just now, so Earlier is empty and says so.
        A.element(app, "library.filter.earlier").tap()
        XCTAssertTrue(A.element(app, "library.filter-empty").waitForExistence(timeout: A.timeout))
        A.element(app, "library.filter.all").tap()

        // The list shows one move a row.
        A.element(app, "library.view.list").tap()
        let first = A.element(app, "library.card.1").frame, second = A.element(app, "library.card.2").frame
        XCTAssertGreaterThan(second.minY, first.maxY - 1, "one a row")
        XCTAssertGreaterThan(first.width, first.height * 4, "a row, not a card: \(first)")
        A.save("library-ipad-list", in: self)
        A.element(app, "library.view.grid").tap()
    }

    @MainActor
    func testIPadPortraitFitsItsWidth() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad layout")
        XCUIDevice.shared.orientation = .portrait
        let app = launchSeeded(22)
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.height, window.width, "portrait")
        XCTAssertGreaterThanOrEqual(cardsInFirstRow(app), 2)
        XCTAssertGreaterThanOrEqual(A.element(app, "library.card.1").frame.width, 176, "cards keep their size")
        A.save("library-ipad-portrait", in: self)
    }

    /// Thirty tactics, flicked through: the scroll's hitch time (informational on a simulator; no baseline is set).
    @MainActor
    func testScrollingThirtyCards() throws {
        let app = launchSeeded(29)
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStop]
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric], options: options) {
            app.swipeUp(velocity: .fast)
            stopMeasuring()
            app.swipeDown(velocity: .fast)
        }
        XCTAssertTrue(A.element(app, "library.card.1").waitForExistence(timeout: A.timeout))
    }

    // MARK: Helpers

    @MainActor private func launchSeeded(_ count: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetLibrary", "YES", "-seedLibrary", "\(count)"]
        app.launch()
        XCTAssertTrue(A.card(app, "Overlap down the left, 5 steps").waitForExistence(timeout: A.timeout))
        sleep(1)
        return app
    }

    /// How many cards share the first card's row.
    @MainActor private func cardsInFirstRow(_ app: XCUIApplication) -> Int {
        let top = A.element(app, "library.card.1").frame.minY
        var count = 0
        for n in 1...12 {
            let card = A.element(app, "library.card.\(n)")
            guard card.exists, abs(card.frame.minY - top) < 0.5 else { break }
            count += 1
        }
        return count
    }
}
