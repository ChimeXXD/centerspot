import XCTest

/// D-74 with a full library (`-seedLibrary N` adds N tactics after the example): small wide cards, 3 a row on an
/// iPhone with at least 9 on screen at once; on an iPad in landscape 6 a row (5 on the 11-inch, whose 6 would be too
/// narrow for numbers) and New tactic at the right of the title. Saves library-*.png to `SHOTS_DIR` (pass it as
/// `TEST_RUNNER_SHOTS_DIR`).
final class LibraryGridUITests: XCTestCase {
    private typealias A = AccessibilityAudit

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testPhoneShowsThreeARowAndNineAtOnce() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "iPhone layout")
        let app = launchSeeded(12)
        let window = app.windows.firstMatch.frame
        let cards = (1...9).map { A.element(app, "library.card.\($0)") }

        for (index, card) in cards.enumerated() {
            XCTAssertTrue(card.exists, "card \(index + 1)")
            XCTAssertTrue(window.contains(card.frame), "card \(index + 1) is on screen: \(card.frame) in \(window)")
        }
        for row in 0..<3 {
            let three = cards[row * 3..<row * 3 + 3].map(\.frame)
            XCTAssertEqual(three[0].minY, three[1].minY, accuracy: 0.5, "row \(row + 1) lines up")
            XCTAssertEqual(three[1].minY, three[2].minY, accuracy: 0.5, "row \(row + 1) lines up")
            XCTAssertLessThan(three[0].maxX, three[1].minX, "row \(row + 1): left to right")
            XCTAssertLessThan(three[1].maxX, three[2].minX, "row \(row + 1): left to right")
            if row > 0 { XCTAssertGreaterThan(three[0].minY, cards[(row - 1) * 3].frame.maxY, "row \(row + 1) is below") }
        }
        // Small and wide: the card is narrower than a third of the window and its pitch wider than tall.
        XCTAssertLessThan(cards[0].frame.width, window.width / 3)
        XCTAssertEqual(cards[0].label, "Overlap down the left, 5 steps", "the example stays on top, with its label")
        XCTAssertEqual(cards[1].label.hasSuffix(", 1 step"), true, cards[1].label)
        A.save("library-compact-iphone", in: self)

        // The press-and-hold menu is still there.
        cards[4].press(forDuration: 1.2)
        for action in ["Rename", "Duplicate", "Share", "Delete"] {
            XCTAssertTrue(app.buttons[action].waitForExistence(timeout: A.timeout), action)
        }
        A.save("library-compact-menu", in: self)
    }

    @MainActor
    func testIPadLandscapeShowsSixARow() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad layout")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launchSeeded(22)
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.width, window.height, "landscape")
        let perRow = cardsInFirstRow(app)
        // 6 from 1300 pt (the 13-inch's 1376); the 11-inch (1210 pt) fits 5 cards that still carry numbers.
        XCTAssertEqual(perRow, window.width >= 1300 ? 6 : 5, "cards in the first row at \(window.width) pt")
        let first = A.element(app, "library.card.1").frame
        XCTAssertGreaterThanOrEqual(first.width, 201, "wide enough for numbers: \(first)")

        // New tactic at the right of the title, on the same band.
        let new = A.element(app, "launch.new").frame, title = A.element(app, "library.title").frame
        XCTAssertGreaterThan(new.minX, window.width / 2, "New tactic sits right: \(new)")
        XCTAssertLessThan(new.minY, title.maxY + 40, "beside the title, not under it: \(new) vs \(title)")
        XCTAssertLessThan(new.maxY, first.minY, "above the cards")
        A.save("library-ipad-landscape", in: self)
    }

    @MainActor
    func testIPadPortraitFitsItsWidth() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad layout")
        XCUIDevice.shared.orientation = .portrait
        let app = launchSeeded(22)
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.height, window.width, "portrait")
        let perRow = cardsInFirstRow(app)
        XCTAssertGreaterThanOrEqual(perRow, 3)
        XCTAssertGreaterThanOrEqual(A.element(app, "library.card.1").frame.width, 201, "wide enough for numbers")
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
