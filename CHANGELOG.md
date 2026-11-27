# Changelog

All notable changes to this project are documented in this file.

## Unreleased

2.0 is a breaking release. The README has a migration guide (1.x to 2.0) with every removed symbol and its replacement.

### Removed

- The Combine publishers on `ApplicationDelegate` (`didBecomeActive`, `didEnterBackground`, `didFinishLaunching`, `didReceiveRemoteNotification` and the rest), its `Subject` typealias and the payload types `LaunchOptions`, `RemoteNotificationRegistration`, `ReceiveRemoteNotification` and `ShortcutAction`. Use SwiftUI's `scenePhase` for lifecycle state and the view modifiers for notifications.
- Home Screen quick action handling (`didRequireShortcutAction`).
- `UserNotificationCenter` and `BufferedPassthroughSubject` from the public API. They are now internal.
- `AppHooksModules.UIApplication`. Use `PlatformApplication`.
- tvOS and watchOS support, and the macOS `RemoteNotificationResult` enum.

### Added

- `ApplicationModuleBootstrap`, which configures modules and throws instead of stopping the app.
- `ApplicationModuleResolver` and `ApplicationModuleResolutionError` as public API, to check a module graph without configuring it. Two new errors: `.duplicateModule` and `.duplicateDependency`.
- `ApplicationModule.key` as a protocol requirement, so a module can declare its own `static let key`.
- `PlatformApplication` in `AppHooksModules`.
- DocC catalogs for both products.
- `Examples/LifecycleHost`, an iOS and macOS app with UI tests that deliver real notifications through the package.

### Changed

- The minimum versions are now iOS 17 and macOS 14.
- `onRegisterDeviceToken(_:)`, `onReceiveRemoteNotification(_:)` and `PushNotification` are iOS only. In 1.x they compiled on macOS and did nothing.
- A device token or notification response that arrives before any view is listening is delivered once, to the first subscriber.
- `onReceiveRemoteNotification(_:)`: when several views handle pushes, the most recently shown one wins. With no handler, the package answers `.noData` instead of leaving the system waiting.
- `userNotificationPresentationOptions(_:)` is active while its view is on screen, and the most recently shown view wins.
- `.modules { }` stops the app when the module graph is invalid or a module throws. In 1.x the error was printed in debug builds and ignored.
- Modules that do not depend on each other are configured in the order they are listed.
- `ApplicationModule.configure(application:)` takes a `PlatformApplication`.
- CI runs on Xcode 27.2, with tests on macOS and the iOS Simulator and a build of the example app.

## 1.1.0

- Added `AppHooksModules` for describing startup work as modules with dependencies.

## 1.0.0 – 1.0.3

- First releases: `ApplicationDelegate` with Combine publishers, and the notification modifiers `onRegisterDeviceToken`, `onReceiveRemoteNotification`, `onUserNotificationResponse` and `userNotificationPresentationOptions`.
