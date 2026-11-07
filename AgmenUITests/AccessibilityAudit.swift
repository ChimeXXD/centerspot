import XCTest

/// Shared steps for `ControlLabelUITests` and `DynamicTypeUITests` (SPEC §8): find elements, check every control on
/// screen has a real VoiceOver label, and save screenshots as attachments (and to `SHOTS_DIR` when it is set).
@MainActor
enum AccessibilityAudit {
    static let timeout: TimeInterval = 15

    /// Kinds of element a person operates. Static text and images are left out: they aren't controls.
    static let controlTypes: Set<XCUIElement.ElementType> = [
        .button, .switch, .toggle, .textField, .secureTextField, .searchField, .textView, .slider, .stepper, .picker,
        .pickerWheel, .segmentedControl, .menuButton, .menuItem, .link, .popUpButton, .tab, .radioButton, .checkBox,
        .disclosureTriangle, .incrementArrow, .decrementArrow, .colorWell, .comboBox,
    ]

    /// SF Symbol names VoiceOver would read out if a control had no label of its own. Labels in Agmen are words with
    /// a capital or a space, so a bare lower-case dotted name ("square.and.arrow.up") or symbol word ("xmark") is one.
    static let symbolPattern = try! NSRegularExpression(pattern: "^(?=.*[a-z])[a-z0-9]+(\\.[a-z0-9]+)*$")

    /// Problems with the labels of every control that is on screen now, as "screen: type 'label' [identifier]".
    static func labelProblems(in app: XCUIApplication, screen: String) -> [String] {
        guard let root = try? app.snapshot() else { return ["\(screen): no snapshot"] }
        let bounds = root.frame
        var problems: [String] = []
        var seen = 0
        walk(root, inside: nil) { node, labelled in
            guard controlTypes.contains(node.elementType), !node.frame.isEmpty,
                  node.frame.intersects(bounds) else { return }
            seen += 1
            // SwiftUI exposes the UIKit control under a labelled Menu or Toggle as an unlabelled child at the same
            // place; VoiceOver reads the labelled parent (Apple's audit below agrees), so the child isn't a gap.
            if let labelled, labelled.contains(CGPoint(x: node.frame.midX, y: node.frame.midY)) { return }
            // A text field is named by its placeholder when it has no label: the system alert's field ("Title")
            // can't take one from SwiftUI, and UIKit and Apple's audit both use the placeholder.
            let spoken = node.label.isEmpty && isTextField(node.elementType) ? node.placeholderValue ?? "" : node.label
            if let problem = problem(label: spoken, identifier: node.identifier) {
                let frame = node.frame.integral
                let extra = "at \(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))×\(Int(frame.height))"
                    + " value '\(node.value.map { "\($0)" } ?? "")' placeholder '\(node.placeholderValue ?? "")'"
                problems.append("\(screen): \(name(node.elementType)) '\(node.label)' [\(node.identifier)] \(problem) \(extra)")
            }
        }
        if seen == 0 { problems.append("\(screen): no controls found on screen") }
        return problems
    }

    private static func isTextField(_ type: XCUIElement.ElementType) -> Bool {
        [.textField, .secureTextField, .searchField, .textView].contains(type)
    }

    /// Why a label isn't one VoiceOver can read well, or nil when it is.
    static func problem(label: String, identifier: String) -> String? {
        let text = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "has no label" }
        if !identifier.isEmpty, text == identifier { return "reads its identifier" }
        let range = NSRange(text.startIndex..., in: text)
        if symbolPattern.firstMatch(in: text, range: range) != nil { return "reads an SF Symbol name" }
        return nil
    }

    /// Visits every node with the frame of its nearest labelled control ancestor, if any.
    private static func walk(_ node: XCUIElementSnapshot, inside labelled: CGRect?,
                             _ visit: (XCUIElementSnapshot, CGRect?) -> Void) {
        visit(node, labelled)
        let isLabelledControl = controlTypes.contains(node.elementType)
            && !node.label.trimmingCharacters(in: .whitespaces).isEmpty
        for child in node.children { walk(child, inside: isLabelledControl ? node.frame : labelled, visit) }
    }

    /// Apple's own audit of what VoiceOver sees: elements without a sufficient description.
    static func descriptionIssues(in app: XCUIApplication, screen: String) -> [String] {
        var issues: [String] = []
        do {
            try app.performAccessibilityAudit(for: .sufficientElementDescription) { issue in
                let element = issue.element.map { "'\($0.label)' [\($0.identifier)] \($0.elementType.rawValue)" } ?? "?"
                issues.append("\(screen): \(issue.compactDescription) on \(element)")
                return true
            }
        } catch {
            issues.append("\(screen): audit failed: \(error)")
        }
        return issues
    }

    private static func name(_ type: XCUIElement.ElementType) -> String {
        switch type {
        case .button: "button"
        case .switch, .toggle: "switch"
        case .textField, .textView, .searchField, .secureTextField: "text field"
        case .menuItem: "menu item"
        case .slider, .stepper: "adjustable"
        default: "control(\(type.rawValue))"
        }
    }

    // MARK: Finding and saving

    static func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// A library card by its VoiceOver label ("<title>, N steps").
    static func card(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'library.card.' AND label == %@", label)).firstMatch
    }

    /// Closes an open menu or popover: its dismiss region when the system offers one, else a tap on the upper pitch,
    /// away from every control (iOS 27 doesn't close a menu on a status bar tap).
    /// A picker menu tall enough to reach the top of the screen is closed by picking its current value again
    /// (`keeping`), which changes nothing.
    static func dismissMenu(_ app: XCUIApplication, keeping current: String? = nil) {
        if let current {
            app.buttons.matching(NSPredicate(format: "label == %@", current)).firstMatch.tap()
            sleep(1)
            return
        }
        let region = app.otherElements["PopoverDismissRegion"]
        if region.exists {
            region.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        }
        sleep(1)  // a tap while the menu is still closing is swallowed
    }

    static func save(_ name: String, in test: XCTestCase) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        test.add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"] {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
