#if os(iOS)
import Foundation
import XCTest

@MainActor
final class DeviceTokenProbeUITests: XCTestCase {
    func testPublicDeviceTokenRetentionAndRemount() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES", "-AppHooksUIDeviceTokenProbe"
        ]
        app.launch()
        try require(app.element("deviceTokenProbeReady"))

        let latestPayload = Data([0x20, 0x21]).base64EncodedString()
        let livePayload = Data([0x30, 0x31]).base64EncodedString()
        let remountPayload = Data([0x40, 0x41]).base64EncodedString()
        app.buttons["deviceTokenSendPreMount"].tap()
        app.buttons["deviceTokenSendLatestPreMount"].tap()

        app.buttons["deviceTokenTogglePrimary"].tap()
        try waitForLabel("mounted", in: app.element("deviceTokenPrimaryStage"))
        try waitForLabel("1", in: app.element("deviceTokenPrimaryCount"))
        try waitForLabel(latestPayload, in: app.element("deviceTokenPrimaryPayload"))
        try waitForLabel("none", in: app.element("deviceTokenPrimaryError"))
        try waitForLabel("true", in: app.element("deviceTokenPrimaryMainThread"))

        app.buttons["deviceTokenToggleSecondary"].tap()
        try waitForLabel("mounted", in: app.element("deviceTokenSecondaryStage"))
        try waitForLabel("0", in: app.element("deviceTokenSecondaryCount"))

        app.buttons["deviceTokenSendLive"].tap()
        try waitForLabel("2", in: app.element("deviceTokenPrimaryCount"))
        try waitForLabel("1", in: app.element("deviceTokenSecondaryCount"))
        try waitForLabel(livePayload, in: app.element("deviceTokenPrimaryPayload"))
        try waitForLabel(livePayload, in: app.element("deviceTokenSecondaryPayload"))
        try waitForLabel("true", in: app.element("deviceTokenPrimaryMainThread"))
        try waitForLabel("true", in: app.element("deviceTokenSecondaryMainThread"))

        app.buttons["deviceTokenSendFailure"].tap()
        try waitForLabel("3", in: app.element("deviceTokenPrimaryCount"))
        try waitForLabel("2", in: app.element("deviceTokenSecondaryCount"))
        try waitForLabel("none", in: app.element("deviceTokenPrimaryPayload"))
        try waitForLabel("registrationFailed:17", in: app.element("deviceTokenPrimaryError"))
        try waitForLabel("registrationFailed:17", in: app.element("deviceTokenSecondaryError"))

        app.buttons["deviceTokenTogglePrimary"].tap()
        app.buttons["deviceTokenToggleSecondary"].tap()
        try waitForLabel("unmounted", in: app.element("deviceTokenPrimaryStage"))
        try waitForLabel("unmounted", in: app.element("deviceTokenSecondaryStage"))
        app.buttons["deviceTokenTogglePrimary"].tap()
        app.buttons["deviceTokenToggleSecondary"].tap()
        try waitForLabel("mounted", in: app.element("deviceTokenPrimaryStage"))
        try waitForLabel("mounted", in: app.element("deviceTokenSecondaryStage"))
        try waitForLabel("3", in: app.element("deviceTokenPrimaryCount"))
        try waitForLabel("2", in: app.element("deviceTokenSecondaryCount"))

        app.buttons["deviceTokenSendRemount"].tap()
        try waitForLabel("4", in: app.element("deviceTokenPrimaryCount"))
        try waitForLabel("3", in: app.element("deviceTokenSecondaryCount"))
        try waitForLabel(remountPayload, in: app.element("deviceTokenPrimaryPayload"))
        try waitForLabel(remountPayload, in: app.element("deviceTokenSecondaryPayload"))
        try waitForLabel("none", in: app.element("deviceTokenPrimaryError"))
        try waitForLabel("none", in: app.element("deviceTokenSecondaryError"))
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
            file: file,
            line: line
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
            file: file,
            line: line
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
