import XCTest

/// D-98 with real taps: a tapped player wears a tag, its position until it has a name. The tag is screen-only and
/// hidden from VoiceOver (the player's label already says it), so this saves `tag-position`, `tag-side` and `tag-name`
/// to `SHOTS_DIR` for the eye. Run with the CenterSpotUITests scheme, on an iPhone and an iPad.
final class PlayerTagUITests: XCTestCase {
    private typealias A = AccessibilityAudit

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTappedPlayerWearsItsPositionThenItsName() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetLibrary", "YES"]
        app.launch()
        let example = A.card(app, "Overlap down the left, 5 steps")
        XCTAssertTrue(example.waitForExistence(timeout: A.timeout))
        example.tap()

        let six = A.element(app, "board.token.h6")
        XCTAssertTrue(six.waitForExistence(timeout: A.timeout))
        six.tap()
        XCTAssertTrue(A.element(app, "selection.edit").waitForExistence(timeout: A.timeout))
        A.save("tag-position", in: self)

        let three = A.element(app, "board.token.h3")
        three.tap()
        A.save("tag-side", in: self)

        three.doubleTap()
        let name = A.element(app, "inspector.name")
        XCTAssertTrue(name.waitForExistence(timeout: A.timeout))
        name.tap()
        name.typeText("Ade")
        A.element(app, "inspector.close").tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: A.timeout))
        sleep(1)
        A.save("tag-name", in: self)
    }
}
