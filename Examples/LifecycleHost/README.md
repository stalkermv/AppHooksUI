# LifecycleHost

A small iOS and macOS app that uses `AppHooksUI` and `AppHooksModules` from this repository. Its UI tests check the package's behavior with real notifications, which unit tests cannot do.

## Running it

Open `LifecycleHost.xcodeproj` and run the `LifecycleHost-iOS` or `LifecycleHost-macOS` scheme. The project uses the package from the repository root, so it always builds against your working copy.

The main screen installs the delegate adaptor, shows SwiftUI's `scenePhase`, and listens for notification responses with a fixed presentation policy.

## UI tests

Each feature has its own screen, which the UI tests open with a launch argument:

| Launch argument | Screen | Platforms |
|---|---|---|
| *(none)* | Main screen | iOS, macOS |
| `-AppHooksUIForegroundPolicyProbe` | Foreground presentation policy | iOS, macOS |
| `-AppHooksUIDeviceTokenProbe` | Device token delivery and remounting | iOS |
| `-AppHooksUIResponseProbe` | Notification responses | iOS |

- **Device token** calls the delegate's registration callbacks with a test token and a test error, and checks what `onRegisterDeviceToken` delivers: a token that arrived before the view was shown is delivered once, a remounted view does not get it again, and two mounted views both get new tokens. It does not talk to APNs.
- **Responses** schedules local notifications, taps each banner and checks the response that `onUserNotificationResponse` receives.
- **Foreground policy** sends a foreground notification through the delegate and checks the presentation options that were chosen.

## Requirements

Xcode 27 or later. The app targets iOS 17 and macOS 14, the same minimums as the package.
