#if os(iOS)
import XCTest

@MainActor
final class RemoteNotificationProbeUITests: XCTestCase {
    func testPublicHandlerReturnsNonNoDataExactlyOnce() throws {
        let app = launchedApplication()
        try sendAndWait(app, result: "failed", handler: "primary")
    }

    func testNoMountedHandlerCompletesWithNoData() throws {
        let app = launchedApplication()
        let toggle = app.buttons["remoteTogglePrimary"]
        try require(toggle)
        toggle.tap()
        try sendAndWait(app, result: "noData")
    }

    func testPrecedenceArbitraryUnmountAndRemount() throws {
        let app = launchedApplication()
        let secondary = app.buttons["remoteToggleSecondary"]
        let tertiary = app.buttons["remoteToggleTertiary"]
        let primary = app.buttons["remoteTogglePrimary"]
        try require(secondary)
        try require(tertiary)
        try require(primary)

        secondary.tap()
        try sendAndWait(app, result: "newData", handler: "secondary")

        tertiary.tap()
        secondary.tap()
        try sendAndWait(app, result: "noData", handler: "tertiary")

        tertiary.tap()
        try sendAndWait(app, result: "failed", handler: "primary")

        primary.tap()
        try sendAndWait(app, result: "noData")

        primary.tap()
        try sendAndWait(app, result: "failed", handler: "primary")
    }

    func testRefreshPreservesMountedHandlerPriority() throws {
        let app = launchedApplication()
        let secondary = app.buttons["remoteToggleSecondary"]
        let refresh = app.buttons["remoteRefreshSecondary"]
        try require(secondary)
        try require(refresh)

        secondary.tap()
        try sendAndWait(app, result: "newData", handler: "secondary")

        refresh.tap()
        try sendAndWait(app, result: "failed", handler: "secondary")
    }

    private func launchedApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        return app
    }

    private func waitForLabel(
        _ label: String,
        in element: XCUIElement,
        timeout: TimeInterval = 10
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func sendAndWait(
        _ app: XCUIApplication,
        result: String,
        handler: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let send = app.buttons["remoteSendNotification"]
        try require(send, file: file, line: line)
        let count = app.descendants(matching: .any)["remoteCompletionCount"]
        try require(count, file: file, line: line)
        let before = try XCTUnwrap(
            Int(count.label),
            "Completion count label is not an integer: \(count.label)",
            file: file,
            line: line
        )

        send.tap()
        XCTAssertTrue(
            waitForLabel("\(before + 1)", in: count),
            "Expected completion count to advance from \(before)",
            file: file,
            line: line
        )
        let resultElement = app.descendants(matching: .any)["remoteCompletionResult"]
        XCTAssertTrue(waitForLabel(result, in: resultElement), file: file, line: line)
        if let handler {
            let handlerElement = app.descendants(matching: .any)["remoteHandler"]
            XCTAssertTrue(waitForLabel(handler, in: handlerElement), file: file, line: line)
        }
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
#endif
