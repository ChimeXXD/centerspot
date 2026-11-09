import XCTest

/// The broadcast restyle (D-65, D-66, D-67) with real taps: the dark pitch in the library and on the board, step 4's
/// marks read out in football words, playback, and Draw › Zone, Line and Glow (each undoable, Cancel takes a session
/// back), then the export sheet without Spotlight. Saves the mockup's frames to `SHOTS_DIR` for comparison with
/// `.proof/design/`. Run with the CenterSpotUITests scheme.
final class BroadcastUITests: XCTestCase {
    private typealias A = AccessibilityAudit

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testBroadcastBoardAndDrawTools() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetLibrary", "YES"]
        app.launch()
        let example = A.card(app, "Overlap down the left, 5 steps")
        XCTAssertTrue(example.waitForExistence(timeout: A.timeout))
        sleep(1)
        A.save("library--broadcast", in: self)

        // Step 4: the lane 3 overlapped into, their back line, rings on 3 and heat where 9 arrives (the mockup's M4).
        example.tap()
        XCTAssertTrue(A.element(app, "board.token.h3").waitForExistence(timeout: A.timeout))
        A.element(app, "steps.chip.4").tap()
        XCTAssertTrue(A.element(app, "board.zone.1").waitForExistence(timeout: A.timeout))
        XCTAssertEqual(A.element(app, "board.zone.1").label, "Zone 1, left wing, step 4")
        XCTAssertEqual(A.element(app, "board.line.1").label, "Line joining their 2, 5 and 4, step 4")
        XCTAssertEqual(A.element(app, "board.glow.1").label, "Glow on number 3, step 4")
        XCTAssertEqual(A.element(app, "board.glow.2").label, "Heat glow, penalty area, step 4")
        tapCentre(app, "board.token.h3")
        XCTAssertTrue(A.element(app, "selection.edit").waitForExistence(timeout: A.timeout))
        sleep(1)
        A.save("board--broadcast", in: self)

        // Playback, paused mid-way through step 4's move.
        A.element(app, "toolbar.play").tap()
        let toggle = A.element(app, "playback.toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: A.timeout))
        toggle.tap()
        A.element(app, "playback.scrubber").coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)).tap()
        XCTAssertTrue(A.element(app, "playback.note").label.hasPrefix("Step 4 of 5"), A.element(app, "playback.note").label)
        XCTAssertFalse(A.element(app, "board.zone.1").exists, "marks aren't separate elements while playing")
        // The flat camera's frame; the broadcast camera's is CameraUITests' (D-76: back to Broadcast after).
        A.element(app, "playback.camera.flat").tap()
        sleep(1)
        A.save("playback--broadcast", in: self)
        A.element(app, "playback.camera.broadcast").tap()
        A.element(app, "playback.done").tap()
        XCTAssertTrue(A.element(app, "steps.chip.4").waitForExistence(timeout: A.timeout))
        A.element(app, "steps.chip.4").tap()

        try drawZone(app)
        try drawLine(app)
        try drawGlow(app)

        // Done keeps everything; Undo takes back the last mark.
        A.element(app, "draw.done").tap()
        XCTAssertTrue(A.element(app, "steps.chip.4").waitForExistence(timeout: A.timeout))
        XCTAssertTrue(A.element(app, "board.glow.4").exists, "the heat dropped on the grass stays: \(glows(app))")
        A.element(app, "nav.undo").tap()
        XCTAssertTrue(A.element(app, "board.glow.4").waitForNonExistence(timeout: A.timeout), "Undo takes the heat back")
        XCTAssertTrue(A.element(app, "board.glow.3").exists)

        // Cancel leaves without changes.
        A.element(app, "toolbar.draw").tap()
        A.element(app, "draw.kind.zone").tap()
        drag(app, from: "board.token.h6", by: CGVector(dx: 50, dy: -40), to: CGVector(dx: 120, dy: 30))
        XCTAssertTrue(A.element(app, "draw.zone.2").waitForExistence(timeout: A.timeout), "a second zone while drawing")
        A.element(app, "draw.cancel").tap()
        XCTAssertTrue(A.element(app, "steps.chip.4").waitForExistence(timeout: A.timeout))
        XCTAssertFalse(A.element(app, "board.zone.2").exists, "Cancel took it back")
        XCTAssertTrue(A.element(app, "board.zone.1").exists)

        // Export: no Spotlight (D-66).
        A.element(app, "toolbar.export").tap()
        XCTAssertTrue(A.element(app, "export.start").waitForExistence(timeout: A.timeout))
        XCTAssertFalse(A.element(app, "export.spotlight").exists)
        // BR-2: the Camera row, on the remembered Broadcast; images stay flat, so it goes for Image.
        XCTAssertTrue(A.element(app, "export.camera.broadcast").isSelected)
        XCTAssertFalse(A.element(app, "export.camera.flat").isSelected)
        sleep(1)
        A.save("export--broadcast", in: self)
        A.element(app, "export.preset.image").tap()
        XCTAssertTrue(A.element(app, "export.camera.broadcast").waitForNonExistence(timeout: A.timeout))
    }

    /// Zone: tap selects step 4's zone (handles, "Zone 1 · step 4", Remove); Remove takes it off; a drag draws a new one.
    @MainActor
    private func drawZone(_ app: XCUIApplication) throws {
        A.element(app, "toolbar.draw").tap()
        XCTAssertTrue(A.element(app, "draw.title").waitForExistence(timeout: A.timeout))
        A.element(app, "draw.kind.zone").tap()
        XCTAssertTrue(A.element(app, "draw.kind.zone").isSelected)
        XCTAssertEqual(A.element(app, "draw.kind-help").label, "Zone · see-through box · drag across the grass")
        XCTAssertEqual(A.element(app, "draw.hint").label, "Drag across the grass to draw a zone.")
        let zone = A.element(app, "draw.zone.1")
        XCTAssertEqual(zone.label, "Zone 1, left wing, step 4")
        zone.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.65)).tap()
        XCTAssertTrue(A.element(app, "draw.mark.label").waitForExistence(timeout: A.timeout))
        XCTAssertEqual(A.element(app, "draw.mark.label").label, "Zone 1 · step 4")
        for corner in ["tl", "tr", "bl", "br"] { XCTAssertTrue(A.element(app, "draw.zone.handle.\(corner)").exists, corner) }
        XCTAssertEqual(A.element(app, "draw.zone.handle.tl").label, "Zone corner, top left")
        sleep(1)
        A.save("draw--tools", in: self)

        A.element(app, "draw.mark.remove").tap()
        XCTAssertTrue(zone.waitForNonExistence(timeout: A.timeout), "Remove takes the zone off the step")
        XCTAssertFalse(A.element(app, "draw.mark.label").exists)
        drag(app, from: "board.token.h7", by: CGVector(dx: -60, dy: -50), to: CGVector(dx: 20, dy: 40))
        XCTAssertTrue(zone.waitForExistence(timeout: A.timeout), "a drag draws a zone")
        XCTAssertEqual(A.element(app, "draw.mark.label").label, "Zone 1 · step 4", "the new zone is selected")
    }

    /// Line: tap 2, then 5 (pending, as in the mockup), then 5 again to finish; a player of the other side starts nothing.
    @MainActor
    private func drawLine(_ app: XCUIApplication) throws {
        A.element(app, "draw.kind.line").tap()
        XCTAssertEqual(A.element(app, "draw.hint").label, "Tap players in order to join them.")
        XCTAssertEqual(A.element(app, "draw.kind-help").label, "Line · joins a unit · tap the last player again to finish")
        tapCentre(app, "board.token.a2")
        tapCentre(app, "board.token.a5")
        sleep(1)
        A.save("draw--tools-line", in: self)
        tapCentre(app, "board.token.a5")
        let line = A.element(app, "draw.line.2")
        XCTAssertTrue(line.waitForExistence(timeout: A.timeout), "the last player again finishes the line")
        XCTAssertEqual(line.label, "Line joining their 2 and 5, step 4")
        tapCentre(app, "board.token.h5")
        tapCentre(app, "board.token.a4")
        XCTAssertTrue(app.staticTexts["One side per line"].waitForExistence(timeout: A.timeout))
    }

    /// Glow: tap 8 for rings (a second tap selects them), then the grass for heat.
    @MainActor
    private func drawGlow(_ app: XCUIApplication) throws {
        A.element(app, "draw.kind.glow").tap()
        XCTAssertFalse(A.element(app, "draw.line.3").exists, "a single tapped player made no line")
        XCTAssertEqual(A.element(app, "draw.hint").label, "Tap a player, or a spot on the grass.")
        tapCentre(app, "board.token.h8")
        let rings = A.element(app, "draw.glow.3")
        XCTAssertTrue(rings.waitForExistence(timeout: A.timeout))
        XCTAssertEqual(rings.label, "Glow on number 8, step 4")
        sleep(1)
        tapCentre(app, "board.token.h8")
        XCTAssertTrue(A.element(app, "draw.mark.label").waitForExistence(timeout: A.timeout))
        XCTAssertEqual(A.element(app, "draw.mark.label").label, "Glow 3 · step 4")
        A.element(app, "board.token.h6").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: 70, dy: 10)).tap()
        XCTAssertTrue(A.element(app, "draw.glow.4").waitForExistence(timeout: A.timeout), "heat on the grass: \(glows(app))")
        XCTAssertTrue(A.element(app, "draw.glow.4").label.hasPrefix("Heat glow, "), A.element(app, "draw.glow.4").label)
        sleep(1)
        A.save("draw--tools-glow", in: self)
    }

    /// A tap at a token's centre. Its element shares the pitch with the marks' elements, so XCUITest would otherwise pick
    /// a point it thinks is uncovered, which can miss the disc.
    @MainActor
    private func tapCentre(_ app: XCUIApplication, _ id: String) {
        A.element(app, id).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// A finger drag on the pitch from `by` off a token's centre to `to` past that.
    @MainActor
    private func drag(_ app: XCUIApplication, from token: String, by start: CGVector, to end: CGVector) {
        let from = A.element(app, token).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(start)
        from.press(forDuration: 0.2, thenDragTo: from.withOffset(CGVector(dx: end.dx - start.dx, dy: end.dy - start.dy)))
    }

    @MainActor
    private func glows(_ app: XCUIApplication) -> [String] {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier CONTAINS '.glow.'")).allElementsBoundByIndex
            .map { "\($0.identifier): \($0.label)" }
    }
}
