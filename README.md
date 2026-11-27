# AppHooksUI

AppHooksUI brings application delegate callbacks into SwiftUI. You install one delegate adaptor in your `App`, and then handle notifications with view modifiers instead of writing delegate code.

The package has two products:

- **AppHooksUI**: notification responses, foreground presentation options, APNs device tokens and background pushes as SwiftUI modifiers.
- **AppHooksModules**: startup work described as modules with dependencies, configured in a predictable order.

App lifecycle state is not part of this package. Use SwiftUI's `scenePhase` with `onChange`.

**Version 2.0 is a breaking release.** See the [migration guide](#migrating-from-1x) before upgrading.

---

## Platforms

| Platform | Minimum |
|---|---|
| iOS | 17.0 |
| macOS | 14.0 |

`onRegisterDeviceToken` and `onReceiveRemoteNotification` are iOS only. tvOS and watchOS are not supported: the delegate APIs this package wraps are not available there.

---

## Installation

### Swift Package Manager

Add the package to the `dependencies` array in your `Package.swift`:

```swift
.package(url: "https://github.com/stalkermv/AppHooksUI", branch: "2.0")
```

2.0 has no tagged release yet, so the requirement points at the `2.0` branch. Once a pre-release is tagged, use `from: "2.0.0-beta.1"` (a plain `from: "2.0.0"` does not resolve pre-releases).

Then add the products you use to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "AppHooksUI", package: "AppHooksUI"),
        .product(name: "AppHooksModules", package: "AppHooksUI"),
    ]
)
```

---

## Getting started

Install `ApplicationDelegate` with the platform adaptor. That is the only setup step. SwiftUI puts the delegate into the environment for you, and the modifiers below read it from there.

```swift
import AppHooksUI
import SwiftUI

@main
struct MyApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) private var appDelegate
    #else
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

If you use one of the modifiers without installing the adaptor, SwiftUI cannot find the delegate in the environment and stops with an error. The package never creates a second delegate behind your back.

---

## Notifications

```swift
import AppHooksUI
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello")
            .onUserNotificationResponse { response in
                print(response.notification.request.identifier)
            }
            .userNotificationPresentationOptions([.banner, .sound])
            #if os(iOS)
            .onRegisterDeviceToken { result in
                switch result {
                case .success(let token):
                    print(token.base64EncodedString())
                case .failure(let error):
                    print("Registration failed: \(error)")
                }
            }
            .onReceiveRemoteNotification { notification in
                print(notification.userInfo)
                return .newData
            }
            #endif
    }
}
```

### `onUserNotificationResponse(perform:)`

Called when the user taps a notification or one of its actions. The action runs on the main actor.

If the response arrives before any view is listening (for example, when a tap launches the app), it is kept and handed to the first view that subscribes. It is delivered once, not replayed to every later view.

### `userNotificationPresentationOptions(_:)`

Decides how a notification is shown while the app is in the foreground. Pass fixed options:

```swift
.userNotificationPresentationOptions([.banner, .sound])
```

or an async closure that looks at the notification:

```swift
.userNotificationPresentationOptions { notification in
    notification.request.content.threadIdentifier == "chat" ? [] : [.banner]
}
```

The policy is active while the view is on screen. If several views set one, the most recently shown view wins. The closure is not guaranteed to run on the main actor.

### `onRegisterDeviceToken(_:)` (iOS)

Receives the APNs device token, or the registration error, as a `Result<Data, Error>`. Like responses, a token that arrives before any view is listening is kept and delivered once to the first subscriber.

### `onReceiveRemoteNotification(_:)` (iOS)

Handles a background push and returns the result to pass back to the system. The closure runs synchronously on the main actor, so it cannot wait for long async work. If several views handle pushes, the most recently shown one wins. If no view is handling pushes, the package answers `.noData`.

### The notification center delegate

`ApplicationDelegate` sets itself up as `UNUserNotificationCenter.current().delegate` when the app launches. If your app sets its own notification center delegate, the response and presentation modifiers will not be called.

---

## Application modules

`AppHooksModules` lets you split startup work (analytics, crash reporting, push setup and so on) into modules. Each module can depend on others, and the package configures them in dependency order.

```swift
import AppHooksModules
import SwiftUI

final class AnalyticsModule: ApplicationModule {
    func configure(application: PlatformApplication) throws {
        // Set up analytics.
    }
}

final class PushModule: ApplicationModule {
    let dependencies = [AnalyticsModule.key]

    func configure(application: PlatformApplication) throws {
        // Set up push, after analytics.
    }
}

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modules {
            AnalyticsModule()
            PushModule()
        }
    }
}
```

`PlatformApplication` is `UIApplication` on iOS and `NSApplication` on macOS. `configure(application:)` runs on the main actor.

A module's key is its type name by default. Declare your own key when it has to stay the same after a rename, or when modules from different packages refer to each other:

```swift
final class AnalyticsModule: ApplicationModule {
    static let key = ApplicationModuleKey(value: "analytics")
    // ...
}
```

### Ordering and errors

Modules without dependencies on each other keep the order you listed them in. The resolver reports a bad setup with `ApplicationModuleResolutionError`:

- `.duplicateModule`: two modules have the same key.
- `.missingDependency`: a module depends on a key that is not registered.
- `.duplicateDependency`: a module lists the same dependency twice.
- `.cyclicDependency`: modules depend on each other in a loop.

`.modules { }` cannot return an error, so any of these (or an error thrown by a module) stops the app. If you want to handle failures yourself, configure the modules directly:

```swift
let bootstrap = ApplicationModuleBootstrap(modules: [AnalyticsModule(), PushModule()])
try bootstrap.configure(application: PlatformApplication.shared)
```

To check a module graph without configuring anything, call `ApplicationModuleResolver(modules:).resolve()`.

SwiftUI can create scene values more than once, so write `configure(application:)` so that running it again is harmless.

---

## Migrating from 1.x

2.0 drops the Combine publishers on `ApplicationDelegate`. Lifecycle state comes from SwiftUI's `scenePhase`, and notification callbacks come from the view modifiers, which keep their 1.x names.

### Setup

Install `ApplicationDelegate` yourself with `@UIApplicationDelegateAdaptor` or `@NSApplicationDelegateAdaptor`, as shown in [Getting started](#getting-started). The modifiers read it from the environment.

### Removed

| Removed in 2.0 | Use instead |
|---|---|
| `didBecomeActive`, `willResignActive`, `didEnterBackground`, `willEnterForeground` publishers | `@Environment(\.scenePhase)` with `onChange(of:)` |
| `willFinishLaunching`, `didFinishLaunching` publishers and `ApplicationDelegate.LaunchOptions` | Your own `App.init()`, or an `ApplicationModule` |
| `willTerminate`, `didReceiveMemoryWarning`, `significantTimeChange`, `protectedDataWillBecomeUnavailable`, `protectedDataDidBecomeAvailable` publishers | The matching `NotificationCenter` notifications, for example `UIApplication.didReceiveMemoryWarningNotification` |
| `didRegisterForRemoteNotifications` publisher and `RemoteNotificationRegistration` | `onRegisterDeviceToken(_:)` |
| `didReceiveRemoteNotification` publisher and `ReceiveRemoteNotification` | `onReceiveRemoteNotification(_:)` |
| `didRequireShortcutAction` publisher and `ShortcutAction` | Not covered by this package |
| `ApplicationDelegate.Subject` | Not needed |
| `UserNotificationCenter` and `receiveResponseNotificationSubject` | `onUserNotificationResponse(perform:)` and `userNotificationPresentationOptions(_:)` |
| `BufferedPassthroughSubject` | Not public any more. Copy the 1.x version into your app if you used it directly |
| `RemoteNotificationResult` on macOS | Not needed, see below |
| `AppHooksModules.UIApplication` | `PlatformApplication` |

### Changed

- The minimum versions are now iOS 17 and macOS 14. tvOS and watchOS are no longer supported.
- `onRegisterDeviceToken(_:)`, `onReceiveRemoteNotification(_:)` and `PushNotification` are iOS only. In 1.x they compiled on macOS and did nothing; now a macOS call is a compile error, so wrap it in `#if os(iOS)`.
- With no view handling background pushes, the package answers `.noData` instead of never calling the system completion handler.
- A device token or notification response that arrives before any view is listening is delivered once to the first subscriber.
- `ApplicationModule.configure(application:)` takes a `PlatformApplication` (the same type as 1.x `UIApplication` on each platform).
- `ApplicationModule` can declare its own `static let key`.
- `.modules { }` stops the app when the module graph is invalid or a module throws. In 1.x the error was only printed in debug builds and ignored. Use `ApplicationModuleBootstrap` to handle errors yourself.
- New public API: `ApplicationModuleBootstrap`, `ApplicationModuleResolver`, `ApplicationModuleResolutionError` and `PlatformApplication` in `AppHooksModules`.

Example of replacing a lifecycle publisher:

```swift
// 1.x
.onReceive(appDelegate.didBecomeActive) { _ in
    refresh()
}

// 2.0
@Environment(\.scenePhase) private var scenePhase

.onChange(of: scenePhase) { _, phase in
    if phase == .active { refresh() }
}
```

---

## Example app

[`Examples/LifecycleHost`](Examples/LifecycleHost) is a small iOS and macOS app that uses the package from this repository, with UI tests that deliver real notifications through it.

---

## License

AppHooksUI is available under the MIT License. See [LICENSE](LICENSE).
