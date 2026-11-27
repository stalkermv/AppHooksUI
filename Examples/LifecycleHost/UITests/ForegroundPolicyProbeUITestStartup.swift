#if os(iOS)
import Foundation
import XCTest

private enum ForegroundProbeStartupError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        guard case let .failed(message) = self else { return nil }
        return message
    }
}

@MainActor
extension XCUIApplication {
    static func foregroundPolicyProbe(
        file: StaticString = #filePath, line: UInt = #line
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES", "-AppHooksUIForegroundPolicyProbe"
        ]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        let authorization = app.descendants(matching: .any)["foregroundProbeAuthorization"]
        let status = app.descendants(matching: .any)["foregroundProbeStatus"]
        var allowPolls = 0
        var allowTaps = 0
        var allowWasVisible = false
        let readiness = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let authorizationLabel = authorization.exists ? authorization.label : "<missing>"
                let allowIsVisible = allow.exists
                allowPolls += 1
                if allowIsVisible && !allowWasVisible {
                    allow.tap()
                    allowTaps += 1
                }
                allowWasVisible = allowIsVisible
                return authorizationLabel == "authorized"
                    || authorizationLabel == "authorization denied"
                    || authorizationLabel == "authorization error"
            },
            object: authorization
        )
        let waitResult = XCTWaiter.wait(for: [readiness], timeout: 60)
        let authorizationLabel = authorization.exists ? authorization.label : "<missing>"
        let statusLabel = status.exists ? status.label : "<missing>"
        if authorizationLabel == "authorized" { return app }

        let outcome = waitResult == .timedOut ? "timed out" : "ended (\(waitResult))"
        try failStartup(
            app,
            message: "Foreground probe startup \(outcome): authorization=\(authorizationLabel), "
                + "status=\(statusLabel), allowPolls=\(allowPolls), allowTaps=\(allowTaps)",
            file: file,
            line: line
        )
    }

    private static func failStartup(
        _ app: XCUIApplication,
        message: String,
        file: StaticString,
        line: UInt
    ) throws -> Never {
        app.terminate()
        let location = "\(String(describing: file)):\(line)"
        throw ForegroundProbeStartupError.failed("\(message) at \(location)")
    }
}
#endif
