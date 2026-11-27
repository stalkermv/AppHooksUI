#if os(iOS)
import UserNotifications
import XCTest

@MainActor
final class ForegroundPolicyProbeUITests: XCTestCase {
    func testReturnedOptionsAndNoPolicy() throws {
        let app = try XCUIApplication.foregroundPolicyProbe(file: #filePath, line: #line)
        let requestID = sendAndWait(app, invocationCount: 1, handler: "primary")

        replayAndWait(
            app,
            replayCount: 1,
            optionsRawValue: UNNotificationPresentationOptions.banner.rawValue,
            requestID: requestID
        )

        app.buttons["foregroundTogglePrimary"].tap()
        replayAndWait(
            app,
            replayCount: 2,
            optionsRawValue: 0,
            requestID: requestID
        )
    }

    func testPrecedenceArbitraryUnmountAndRemount() throws {
        let app = try XCUIApplication.foregroundPolicyProbe(file: #filePath, line: #line)
        var invocationCount = 0
        var previousRequestID: String?

        invocationCount += 1
        previousRequestID = sendAndWait(
            app,
            invocationCount: invocationCount,
            handler: "primary",
            previousRequestID: previousRequestID
        )
        app.buttons["foregroundToggleSecondary"].tap()
        app.buttons["foregroundToggleTertiary"].tap()

        invocationCount += 1
        previousRequestID = sendAndWait(
            app,
            invocationCount: invocationCount,
            handler: "tertiary",
            previousRequestID: previousRequestID
        )
        app.buttons["foregroundToggleSecondary"].tap()

        invocationCount += 1
        previousRequestID = sendAndWait(
            app,
            invocationCount: invocationCount,
            handler: "tertiary",
            previousRequestID: previousRequestID
        )
        app.buttons["foregroundToggleTertiary"].tap()

        invocationCount += 1
        previousRequestID = sendAndWait(
            app,
            invocationCount: invocationCount,
            handler: "primary",
            previousRequestID: previousRequestID
        )
        app.buttons["foregroundTogglePrimary"].tap()
        app.buttons["foregroundTogglePrimary"].tap()

        invocationCount += 1
        previousRequestID = sendAndWait(
            app,
            invocationCount: invocationCount,
            handler: "primary",
            previousRequestID: previousRequestID
        )
    }

    func testRefreshOlderAndSelectedOptions() throws {
        let app = try XCUIApplication.foregroundPolicyProbe(file: #filePath, line: #line)
        app.buttons["foregroundToggleSecondary"].tap()
        let firstRequestID = sendAndWait(app, invocationCount: 1, handler: "secondary")
        replayAndWait(
            app,
            replayCount: 1,
            optionsRawValue: UNNotificationPresentationOptions.banner.union(.sound).rawValue,
            requestID: firstRequestID
        )

        app.buttons["foregroundRefreshPrimary"].tap()
        let secondRequestID = sendAndWait(app, invocationCount: 3, handler: "secondary")
        XCTAssertNotEqual(firstRequestID, secondRequestID)

        app.buttons["foregroundRefreshSecondary"].tap()
        let thirdRequestID = sendAndWait(app, invocationCount: 4, handler: "secondary")
        replayAndWait(
            app,
            replayCount: 2,
            optionsRawValue: UNNotificationPresentationOptions.banner.rawValue,
            requestID: thirdRequestID
        )
    }

    func testInFlightRefreshKeepsOriginalSnapshot() throws {
        let app = try XCUIApplication.foregroundPolicyProbe(file: #filePath, line: #line)
        app.buttons["foregroundToggleInFlight"].tap()
        let firstRequestID = sendAndWait(app, invocationCount: 1, handler: "inFlight")

        app.buttons["foregroundArmInFlight"].tap()
        defer { releaseGateIfPresent(app) }
        app.buttons["foregroundReplayLatest"].tap()

        XCTAssertTrue(
            waitForLabel(
                "2", in: app.descendants(matching: .any)["foregroundInvocationCount"]
            )
        )
        XCTAssertTrue(
            waitForLabel(
                "1", in: app.descendants(matching: .any)["foregroundInFlightStartCount"]
            )
        )

        app.buttons["foregroundRefreshInFlight"].tap()
        releaseGateIfPresent(app)
        replayAndWait(
            app,
            replayCount: 1,
            optionsRawValue: UNNotificationPresentationOptions.banner.rawValue,
            requestID: firstRequestID,
            startReplay: false
        )

        let secondRequestID = sendAndWait(app, invocationCount: 3, handler: "inFlight")
        replayAndWait(
            app,
            replayCount: 2,
            optionsRawValue: UNNotificationPresentationOptions.list.rawValue,
            requestID: secondRequestID
        )
    }

    func testInFlightUnmountRestoresPredecessor() throws {
        let app = try XCUIApplication.foregroundPolicyProbe(file: #filePath, line: #line)
        app.buttons["foregroundToggleInFlight"].tap()
        let firstRequestID = sendAndWait(app, invocationCount: 1, handler: "inFlight")

        app.buttons["foregroundArmInFlight"].tap()
        defer { releaseGateIfPresent(app) }
        app.buttons["foregroundReplayLatest"].tap()

        XCTAssertTrue(
            waitForLabel(
                "2", in: app.descendants(matching: .any)["foregroundInvocationCount"]
            )
        )
        XCTAssertTrue(
            waitForLabel(
                "1", in: app.descendants(matching: .any)["foregroundInFlightStartCount"]
            )
        )

        app.buttons["foregroundToggleInFlight"].tap()
        releaseGateIfPresent(app)
        replayAndWait(
            app,
            replayCount: 1,
            optionsRawValue: UNNotificationPresentationOptions.banner.rawValue,
            requestID: firstRequestID,
            startReplay: false
        )

        let secondRequestID = sendAndWait(app, invocationCount: 3, handler: "primary")
        replayAndWait(
            app,
            replayCount: 2,
            optionsRawValue: UNNotificationPresentationOptions.banner.rawValue,
            requestID: secondRequestID
        )
    }

    private func sendAndWait(
        _ app: XCUIApplication,
        invocationCount: Int,
        handler: String,
        previousRequestID: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String {
        app.buttons["foregroundSendNotification"].tap()
        let count = app.descendants(matching: .any)["foregroundInvocationCount"]
        XCTAssertTrue(
            waitForLabel("\(invocationCount)", in: count, timeout: 20),
            file: file,
            line: line
        )
        let selected = app.descendants(matching: .any)["foregroundSelectedHandler"]
        XCTAssertTrue(
            waitForLabel(handler, in: selected, timeout: 20), file: file, line: line
        )
        let requestID = app.descendants(matching: .any)["foregroundLastRequestID"].label
        let scheduledRequestID = app.descendants(matching: .any)["foregroundScheduledRequestID"].label
        XCTAssertNotEqual(requestID, "none", file: file, line: line)
        XCTAssertNotEqual(scheduledRequestID, "none", file: file, line: line)
        XCTAssertEqual(requestID, scheduledRequestID, file: file, line: line)
        if let previousRequestID {
            XCTAssertNotEqual(requestID, previousRequestID, file: file, line: line)
        }
        return requestID
    }

    private func replayAndWait(
        _ app: XCUIApplication,
        replayCount: Int,
        optionsRawValue: UInt,
        requestID: String,
        startReplay: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if startReplay { app.buttons["foregroundReplayLatest"].tap() }
        let count = app.descendants(matching: .any)["foregroundReplayCount"]
        XCTAssertTrue(
            waitForLabel("\(replayCount)", in: count, timeout: 20),
            file: file,
            line: line
        )
        let actualOptions = app.descendants(matching: .any)["foregroundReplayOptionsRawValue"]
        XCTAssertTrue(
            waitForLabel("\(optionsRawValue)", in: actualOptions, timeout: 20),
            file: file,
            line: line
        )
        let actualRequestID = app.descendants(matching: .any)["foregroundReplayRequestID"].label
        XCTAssertEqual(actualRequestID, requestID, file: file, line: line)
    }

    private func releaseGateIfPresent(_ app: XCUIApplication) {
        let release = app.buttons["foregroundReleaseInFlight"]
        guard release.waitForExistence(timeout: 2) else { return }
        release.tap()
    }

    private func waitForLabel(
        _ label: String,
        in element: XCUIElement,
        timeout: TimeInterval = 10
    ) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label), object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
#endif
