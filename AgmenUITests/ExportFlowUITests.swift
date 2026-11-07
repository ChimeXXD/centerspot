import XCTest

/// D5-4 (SPEC §10): open the hero move, Export, check the estimate before export, export with an honest frame count,
/// cancel (back to the choices), export again, see the real size, and the image preset. Saves export.png,
/// export-rendering.png, export-done.png and export-error.png (as `BoardScreenshotUITests` does). Launches with
/// `-exportFrameDelay` so the rendering state lasts long enough to see and cancel.
final class ExportFlowUITests: XCTestCase {
    private let timeout: TimeInterval = 15

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testExportFlow() throws {
        let app = launch(["-exportFrameDelay", "40"])
        element(app, "toolbar.export").tap()

        // Before export: Vertical 9:16 chosen, the estimate and the length.
        let start = element(app, "export.start")
        XCTAssertTrue(start.waitForExistence(timeout: timeout))
        XCTAssertEqual(start.label, "Export video")
        XCTAssertTrue(element(app, "export.preset.vertical").isSelected, "Vertical 9:16 is the default")
        XCTAssertEqual(element(app, "export.preset.vertical").label, "Vertical 9:16")
        XCTAssertEqual(element(app, "export.size").label, "Up to 4 MB · 8 s · 1080 × 1920")
        XCTAssertEqual(element(app, "export.size-help").label, "Estimate. Plays in WhatsApp and Discord.")
        XCTAssertTrue(element(app, "export.preview").exists)
        sleep(1)
        save("export")

        // Rendering, with the real count, then Cancel goes back to the choices.
        start.tap()
        let progress = element(app, "export.progress")
        XCTAssertTrue(progress.waitForExistence(timeout: timeout))
        XCTAssertTrue(progress.waitForLabel(matching: "Rendering \\d+ of 240 frames", timeout: timeout), progress.label)
        sleep(3)
        XCTAssertTrue(element(app, "export.progress-help").label.hasSuffix("Keep Agmen open until it's done."))
        save("export-rendering")
        element(app, "export.cancel").tap()
        XCTAssertTrue(start.waitForExistence(timeout: timeout), "Cancel returns to the choices")
        XCTAssertFalse(progress.exists)

        // Export again to the end: the real size before sharing.
        start.tap()
        let done = element(app, "export.done")
        XCTAssertTrue(done.waitForExistence(timeout: 60))
        XCTAssertEqual(done.label, "Video ready")
        let size = element(app, "export.done-size")
        XCTAssertNotNil(size.label.range(of: "^\\d+\\.\\d MB · 8 s · 1080 × 1920$", options: .regularExpression), size.label)
        XCTAssertTrue(element(app, "export.share").exists)
        XCTAssertEqual(element(app, "export.save").label, "Save to Photos")
        sleep(1)
        save("export-done")

        // The share sheet opens with the file.
        element(app, "export.share").tap()
        let shareSheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: timeout), "the system share sheet")
        save("export-share")
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(shareSheet.waitForNonExistence(timeout: timeout))

        // Save to Photos (Chime's phone, 7 Nov: the app quit here). Accept the add-only prompt if iOS shows it.
        element(app, "export.save").tap()
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 15), "iOS asks to add to Photos")
        allow.tap()
        XCTAssertTrue(element(app, "export.save").waitForLabel(matching: "^Saved to Photos$", timeout: 20),
                      "saved: \(element(app, "export.save").label)")
        XCTAssertEqual(app.state, .runningForeground, "the app is still running")

        // Close, reopen: the image preset.
        element(app, "export.close").tap()
        XCTAssertTrue(element(app, "toolbar.export").waitForExistence(timeout: timeout))
        element(app, "toolbar.export").tap()
        XCTAssertTrue(element(app, "export.preset.image").waitForExistence(timeout: timeout))
        element(app, "export.preset.image").tap()
        XCTAssertEqual(element(app, "export.start").label, "Export image")
        XCTAssertNotNil(element(app, "export.size").label.range(of: "^PNG · \\d+ × \\d+$", options: .regularExpression),
                        element(app, "export.size").label)
        save("export-image")
        element(app, "export.start").tap()
        XCTAssertTrue(element(app, "export.done").waitForExistence(timeout: timeout))
        XCTAssertEqual(element(app, "export.done").label, "Image ready")
        XCTAssertNotNil(element(app, "export.done-size").label.range(of: "^\\d+\\.\\d MB · \\d+ × \\d+$", options: .regularExpression),
                        element(app, "export.done-size").label)
        save("export-image-done")
    }

    /// The error state and its way out (debug `-exportFails` fails the export at frame 10).
    @MainActor
    func testExportError() throws {
        let app = launch(["-exportFails", "YES"])
        element(app, "toolbar.export").tap()
        let start = element(app, "export.start")
        XCTAssertTrue(start.waitForExistence(timeout: timeout))
        start.tap()
        let error = element(app, "export.error")
        XCTAssertTrue(error.waitForExistence(timeout: timeout))
        XCTAssertEqual(error.label, "Couldn't make the video. Try again, or export an image.")
        XCTAssertTrue(element(app, "export.retry").exists)
        sleep(1)
        save("export-error")
        element(app, "export.image").tap()
        XCTAssertTrue(element(app, "export.preset.image").waitForExistence(timeout: timeout))
        XCTAssertTrue(element(app, "export.preset.image").isSelected, "the way out picks Image")
        XCTAssertEqual(element(app, "export.start").label, "Export image")
    }

    @MainActor private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        // Every run asks for Photos afresh, so the permission prompt in Save to Photos is tested each time.
        app.resetAuthorizationStatus(for: .photos)
        app.launchArguments = ["-resetLibrary", "YES", "-openExample", "YES"] + arguments
        app.launch()
        XCTAssertTrue(element(app, "board.token.h3").waitForExistence(timeout: timeout), "the hero move opens")
        return app
    }

    @MainActor private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor private func save(_ name: String) {
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
    func waitForLabel(matching pattern: String, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label MATCHES %@", pattern), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
