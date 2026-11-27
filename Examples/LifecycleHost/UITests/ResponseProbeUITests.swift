#if os(iOS)
import UserNotifications
import XCTest

private enum ResponseProbeStartupError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        guard case let .failed(message) = self else { return nil }
        return message
    }
}

@MainActor
final class ResponseProbeUITests: XCTestCase {
    func testPublicResponseReplayConsumers() throws {
        let app = try launchedApplication()
        try waitForLabel("mounted", in: app.element("responseCaptureStage"))
        try waitForLabel("unmounted", in: app.element("responsePrimaryStage"))
        try waitForLabel("unmounted", in: app.element("responseSecondaryStage"))

        let first = try scheduleAndCapture(app, expectedCaptureCount: 1)
        let second = try scheduleAndCapture(app, expectedCaptureCount: 2)
        let third = try scheduleAndCapture(app, expectedCaptureCount: 3)
        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(second, third)
        XCTAssertNotEqual(first, third)

        app.buttons["responseToggleCapture"].tap()
        try waitForLabel("unmounted", in: app.element("responseCaptureStage"))

        try replayAndWait(
            app, button: "responseReplayR1", acknowledgementCount: 1,
            requestID: first, consumerCount: 0
        )
        try replayAndWait(
            app, button: "responseReplayR2", acknowledgementCount: 2,
            requestID: second, consumerCount: 0
        )

        app.buttons["responseTogglePrimary"].tap()
        try waitForLabel("mounted", in: app.element("responsePrimaryStage"))
        try waitForLabel("1", in: app.element("responsePrimaryCount"))
        try waitForLabel(second, in: app.element("responsePrimaryRequestID"))
        try waitForLabel("true", in: app.element("responsePrimaryMainThread"))

        app.buttons["responseToggleSecondary"].tap()
        try waitForLabel("mounted", in: app.element("responseSecondaryStage"))
        try replayAndWait(
            app, button: "responseReplayR1", acknowledgementCount: 3,
            requestID: first, consumerCount: 3, primaryCount: 2, secondaryCount: 1
        )

        app.buttons["responseTogglePrimary"].tap()
        try waitForLabel("unmounted", in: app.element("responsePrimaryStage"))
        try waitForLabel("mounted", in: app.element("responseSecondaryStage"))
        try replayAndWait(
            app, button: "responseReplayR2", acknowledgementCount: 4,
            requestID: second, consumerCount: 4, primaryCount: 2, secondaryCount: 2,
            primaryRequestID: first
        )

        app.buttons["responseTogglePrimary"].tap()
        try waitForLabel("mounted", in: app.element("responsePrimaryStage"))
        try waitForLabel("mounted", in: app.element("responseSecondaryStage"))
        try replayAndWait(
            app, button: "responseReplayR3", acknowledgementCount: 5,
            requestID: third, consumerCount: 6, primaryCount: 3, secondaryCount: 3
        )
    }

    private func launchedApplication(
        file: StaticString = #filePath, line: UInt = #line
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES", "-AppHooksUIResponseProbe"
        ]
        app.launch()
        let authorization = app.element("responseAuthorization")
        let status = app.element("responseStatus")
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
        var allowWasVisible = false
        let readiness = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let visible = allow.exists
                if visible && !allowWasVisible { allow.tap() }
                allowWasVisible = visible
                let label = authorization.exists ? authorization.label : "<missing>"
                return label == "authorized"
                    || label == "authorization denied"
                    || label == "authorization error"
            },
            object: authorization
        )
        let waitResult = XCTWaiter.wait(for: [readiness], timeout: 60)
        let authorizationLabel = authorization.exists ? authorization.label : "<missing>"
        let statusLabel = status.exists ? status.label : "<missing>"
        guard authorizationLabel == "authorized" else {
            app.terminate()
            throw ResponseProbeStartupError.failed(
                "Response probe startup ended \(waitResult): "
                    + "authorization=\(authorizationLabel), status=\(statusLabel) "
                    + "at \(String(describing: file)):\(line)"
            )
        }
        try require(app.element("responseReady"), file: file, line: line)
        try waitForLabel("installed", in: app.element("responseDelegateReady"), file: file, line: line)
        return app
    }

    private func scheduleAndCapture(
        _ app: XCUIApplication,
        expectedCaptureCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let schedule = app.buttons["responseScheduleNotification"]
        try require(schedule, file: file, line: line)
        schedule.tap()
        let scheduledID = try requiredLabel(
            app.element("responseScheduledRequestID"), file: file, line: line
        )
        XCTAssertNotEqual(scheduledID, "none", file: file, line: line)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let banner = springboard.staticTexts[scheduledID].firstMatch
        try require(banner, timeout: 30, file: file, line: line)
        banner.tap()
        try waitForLabel(
            "\(expectedCaptureCount)", in: app.element("responseCaptureCount"),
            file: file, line: line
        )
        let capturedID = try requiredLabel(
            app.element("responseCaptureRequestID"), file: file, line: line
        )
        XCTAssertEqual(capturedID, scheduledID, file: file, line: line)
        try waitForLabel(
            UNNotificationDefaultActionIdentifier,
            in: app.element("responseCaptureAction"), file: file, line: line
        )
        try waitForLabel("true", in: app.element("responseCaptureMainThread"), file: file, line: line)
        return capturedID
    }

    private func replayAndWait(
        _ app: XCUIApplication,
        button: String,
        acknowledgementCount: Int,
        requestID: String,
        consumerCount: Int? = nil,
        primaryCount: Int? = nil,
        secondaryCount: Int? = nil,
        primaryRequestID: String? = nil,
        secondaryRequestID: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let beforeActions = try requiredInt(app.element("responseConsumerReceiptCount"), file: file, line: line)
        try require(app.buttons[button], file: file, line: line)
        app.buttons[button].tap()
        try assertAcknowledgement(
            app,
            acknowledgementCount: acknowledgementCount,
            requestID: requestID,
            consumerActionsBeforeReturn: beforeActions,
            file: file, line: line
        )
        if let consumerCount {
            try waitForLabel(
                "\(consumerCount)", in: app.element("responseConsumerReceiptCount"),
                file: file, line: line
            )
        }
        if let primaryCount {
            try waitForLabel(
                "\(primaryCount)", in: app.element("responsePrimaryCount"),
                file: file, line: line
            )
            try waitForLabel(
                primaryRequestID ?? requestID,
                in: app.element("responsePrimaryRequestID"), file: file, line: line
            )
            try waitForLabel("true", in: app.element("responsePrimaryMainThread"), file: file, line: line)
        }
        if let secondaryCount {
            try waitForLabel(
                "\(secondaryCount)", in: app.element("responseSecondaryCount"),
                file: file, line: line
            )
            if secondaryCount > 0 {
                try waitForLabel(
                    secondaryRequestID ?? requestID,
                    in: app.element("responseSecondaryRequestID"), file: file, line: line
                )
                try waitForLabel(
                    "true", in: app.element("responseSecondaryMainThread"), file: file, line: line
                )
            }
        }
        try waitForLabel(
            "\(acknowledgementCount)", in: app.element("responseAckObservedCount"),
            file: file, line: line
        )
    }
}

extension ResponseProbeUITests {
    private func assertAcknowledgement(
        _ app: XCUIApplication,
        acknowledgementCount: Int,
        requestID: String,
        consumerActionsBeforeReturn: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try waitForLabel(
            "\(acknowledgementCount)", in: app.element("responseAckReturnCount"),
            file: file, line: line
        )
        try waitForLabel(requestID, in: app.element("responseAckRequestID"), file: file, line: line)
        try waitForLabel(
            UNNotificationDefaultActionIdentifier,
            in: app.element("responseAckAction"), file: file, line: line
        )
        try waitForLabel("true", in: app.element("responseAckMainThread"), file: file, line: line)
        let atReturn = try requiredInt(app.element("responseActionsAtReturn"), file: file, line: line)
        XCTAssertEqual(
            try requiredInt(app.element("responseActionsBeforeReturn"), file: file, line: line),
            atReturn, file: file, line: line
        )
        XCTAssertEqual(atReturn, consumerActionsBeforeReturn, file: file, line: line)
    }

    private func waitForLabel(
        _ label: String,
        in element: XCUIElement,
        timeout: TimeInterval = 20,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try require(element, file: file, line: line)
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label), object: element
        )
        _ = try XCTUnwrap(
            XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed ? true : nil,
            "Timed out waiting for '\(label)'; observed '\(element.label)'",
            file: file, line: line
        )
    }

    private func requiredLabel(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        try require(element, file: file, line: line)
        return try XCTUnwrap(
            element.label.isEmpty ? nil : element.label,
            "Required UI element has an empty label: \(element.identifier)",
            file: file, line: line
        )
    }

    private func requiredInt(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Int {
        return try XCTUnwrap(
            Int(try requiredLabel(element, file: file, line: line)),
            "Expected integer label from \(element.identifier)",
            file: file, line: line
        )
    }

    private func require(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        _ = try XCTUnwrap(
            element.waitForExistence(timeout: timeout) ? element : nil,
            "Required UI element is unavailable: \(element.identifier)",
            file: file, line: line
        )
    }
}

@MainActor
private extension XCUIApplication {
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier]
    }
}
#endif
