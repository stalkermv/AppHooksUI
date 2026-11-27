import XCTest

@MainActor
final class LifecycleHostUITests: XCTestCase {
    func testNativeEnvironmentAndLifecycle() throws {
        let app = XCUIApplication()
        try launch(app)
        let phase = app.descendants(matching: .any)["applicationPhase"]
        try require(phase)
        try waitForLabel("active", element: phase)
        try waitForLabel(
            "mounted", element: app.descendants(matching: .any)["initialStage"]
        )
        let delegateLabel = try requiredLabel(
            app.descendants(matching: .any)["delegateReady"]
        )
        XCTAssertTrue(delegateLabel.contains("ApplicationDelegate"), delegateLabel)
        try waitForLabel(
            "installed", element: app.descendants(matching: .any)["notificationDelegateReady"]
        )

        #if os(iOS)
        XCUIDevice.shared.press(.home)
        try waitForAnyLabel(["inactive", "background"], element: phase)
        try waitForLabel("background", element: phase)
        #else
        app.typeKey("h", modifierFlags: .command)
        XCUIApplication(bundleIdentifier: "com.apple.finder").activate()
        try waitForNonForeground(app)
        try waitForAnyLabel(["inactive", "background"], element: phase)
        #endif
        app.activate()
        try waitForLabel("active", element: phase)
        let history = try requiredLabel(app.descendants(matching: .any)["phaseHistory"])
        XCTAssertTrue(history.contains("inactive"), history)
        #if os(iOS)
        XCTAssertTrue(history.contains("background"), history)
        #endif
    }

    func testInitialDeliveryOnRemount() throws {
        let app = XCUIApplication()
        try launch(app)
        let phase = app.descendants(matching: .any)["applicationPhase"]
        try require(phase)
        #if os(macOS)
        try requireInputReady(app)
        #endif
        try waitForLabel("active", element: phase)
        try waitForLabel(
            "mounted", element: app.descendants(matching: .any)["initialStage"]
        )
        let count = app.descendants(matching: .any)["initialCount"]
        let before = try XCTUnwrap(
            Int(try requiredLabel(count)),
            "Initial delivery count is not an integer",
            file: #filePath,
            line: #line
        )
        let historyBefore = try requiredLabel(
            app.descendants(matching: .any)["phaseHistory"]
        )
        try toggleHandler(app)
        try waitForLabel(
            "unmounted", element: app.descendants(matching: .any)["initialStage"]
        )
        try toggleHandler(app)
        try waitForLabel(
            "mounted", element: app.descendants(matching: .any)["initialStage"]
        )
        try waitForLabel("\(before + 1)", element: count)
        let historyAfter = try requiredLabel(
            app.descendants(matching: .any)["phaseHistory"]
        )
        XCTAssertEqual(historyAfter, historyBefore)
    }

    #if os(macOS)
    /// Activates the app and requires it foreground with a reachable window
    /// before the baseline is read.
    private func requireInputReady(_ app: XCUIApplication) throws {
        app.activate()
        try waitForCondition("the app is running foreground") {
            app.state == .runningForeground
        }
        try waitForCondition("the app owns a hittable window") {
            let window = app.windows.firstMatch
            return window.exists && window.isHittable
        }
    }
    #endif

    /// Activates the toggle with the platform's own input. macOS verifies the
    /// target and clicks; iOS taps exactly as before.
    private func toggleHandler(_ app: XCUIApplication) throws {
        #if os(macOS)
        try requireTargetReady(app.buttons["toggleHandler"])
        app.buttons["toggleHandler"].click()
        #else
        app.buttons["toggleHandler"].tap()
        #endif
    }

    #if os(macOS)
    private func requireTargetReady(_ element: XCUIElement) throws {
        try waitForCondition("the toggle control exists and is hittable") {
            element.exists && element.isHittable
        }
    }
    #endif

    /// Bounded wait that throws on timeout, so a failed precondition stops the
    /// test instead of letting it interact anyway.
    private func waitForCondition(
        _ description: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        predicate: @escaping () -> Bool
    ) throws {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in predicate() }, object: nil
        )
        _ = try XCTUnwrap(
            XCTWaiter.wait(for: [expectation], timeout: 10) == .completed ? true : nil,
            "Precondition not satisfied: \(description)",
            file: file,
            line: line
        )
    }

    private func launch(_ app: XCUIApplication) throws {
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        #if os(macOS)
        if !app.descendants(matching: .any)["applicationPhase"].waitForExistence(timeout: 3) {
            app.typeKey("n", modifierFlags: .command)
        }
        #endif
        try require(app.descendants(matching: .any)["applicationPhase"])
    }

    #if os(iOS)
    func testPresentationPolicyUpdatesWithoutRemount() throws {
        let app = XCUIApplication()
        try launch(app)
        try sendNotification(in: app)
        try waitForLabel("shown", element: app.descendants(matching: .any)["presentationResult"])
        app.buttons["togglePresentation"].tap()
        try sendNotification(in: app)
        try waitForLabel("hidden", element: app.descendants(matching: .any)["presentationResult"])
    }

    func testNotificationResponseReachesMountedView() throws {
        let app = XCUIApplication()
        try launch(app)
        try sendNotification(in: app)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let banner = springboard.staticTexts["AppHooksUI verification"].firstMatch
        try require(banner)
        banner.tap()
        try waitForLabel("1", element: app.descendants(matching: .any)["responseCount"])
    }

    private func sendNotification(in app: XCUIApplication) throws {
        try require(app.buttons["sendNotification"])
        app.buttons["sendNotification"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 2) { allow.tap() }
    }
    #endif

    private func waitForLabel(
        _ label: String,
        element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try require(element, file: file, line: line)
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in element.label == label }, object: nil
        )
        _ = try XCTUnwrap(
            XCTWaiter.wait(for: [expectation], timeout: 10) == .completed ? true : nil,
            "Timed out waiting for label '\(label)'; observed '\(element.label)'",
            file: file,
            line: line
        )
    }

    private func waitForAnyLabel(
        _ labels: [String],
        element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try require(element, file: file, line: line)
        let predicate = NSPredicate(
            block: { _, _ in labels.contains(element.label) }
        )
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        _ = try XCTUnwrap(
            XCTWaiter.wait(for: [expectation], timeout: 10) == .completed ? true : nil,
            "Timed out waiting for one of labels \(labels); observed '\(element.label)'",
            file: file,
            line: line
        )
    }

    #if os(macOS)
    private func waitForNonForeground(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in app.state != .runningForeground },
            object: nil
        )
        _ = try XCTUnwrap(
            XCTWaiter.wait(for: [expectation], timeout: 10) == .completed ? true : nil,
            "Timed out waiting for application process to leave foreground; observed '\(app.state)'",
            file: file,
            line: line
        )
    }
    #endif

    private func requiredLabel(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        try require(element, file: file, line: line)
        return try XCTUnwrap(
            element.label.isEmpty ? nil : element.label,
            "Required UI element has an empty accessibility label: \(element.identifier)",
            file: file,
            line: line
        )
    }

    private func require(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        _ = try XCTUnwrap(
            element.waitForExistence(timeout: 10) ? element : nil,
            "Required UI element is unavailable: \(element.identifier)",
            file: file,
            line: line
        )
    }
}
