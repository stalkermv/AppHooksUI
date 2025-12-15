# AppHooksUI

AppHooksUI brings the imperative application lifecycle APIs that iOS/tvOS/macOS/watchOS apps rely on into a declarative SwiftUI-friendly world. It provides a drop-in application delegate, strongly typed notification hooks, and a new AppHooksModules product for describing startup modules with dependency resolution.

## Features
- **Unified `ApplicationDelegate`:** Share one delegate implementation across iOS & macOS apps and expose lifecycle events via Combine publishers.
- **SwiftUI view modifiers:** Handle push registration, background pushes, and `UNUserNotificationCenter` callbacks directly inside views using `.onRegisterDeviceToken`, `.onReceiveRemoteNotification`, `.onUserNotificationResponse`, and `.userNotificationPresentationOptions`.
- **Buffered delivery utilities:** `BufferedPassthroughSubject` ensures delegate events survive the gap before a SwiftUI hierarchy subscribes.
- **Declarative application modules:** Ship reusable startup configuration blocks with automatic dependency sorting via the `AppHooksModules` target.

## Installation
Add the package through Xcode (`File ▸ Add Packages…`) or by editing your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/stalkermv/AppHooksUI.git", branch: "development")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "AppHooksUI", package: "AppHooksUI"),
            .product(name: "AppHooksModules", package: "AppHooksUI") // optional but recommended
        ])
]
```

## Getting started

### 1. Bootstrap AppHooksUI

```swift
import AppHooksUI

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

`ApplicationDelegate` is automatically connected to the SwiftUI app lifecycle, so the view hierarchy can consume AppHooksUI publishers and modifiers without manual adaptors or environment plumbing.

### 2. React to push notifications in SwiftUI

```swift
import AppHooksUI

struct ContentView: View {
    var body: some View {
        Text("Push-ready")
            .onRegisterDeviceToken { result in
                // success -> Data, failure -> Error
            }
            .onReceiveRemoteNotification { notification in
                // Inspect notification.userInfo
                return .newData
            }
            .onUserNotificationResponse { response in
                print("User interacted with \(response.notification.request.identifier)")
            }
            .userNotificationPresentationOptions([.alert, .sound])
    }
}
```

## Application modules (`AppHooksModules`)

`AppHooksModules` introduces a lightweight dependency resolver for startup logic. Define modules that describe their dependencies and SwiftUI will configure them in topological order.

```swift
import AppHooksModules

final class AnalyticsModule: ApplicationModule {
    func configure(application: UIApplication) throws {
        // bootstrap analytics SDK
    }
}

final class PushModule: ApplicationModule {
    let dependencies = [AnalyticsModule.key]

    func configure(application: UIApplication) throws {
        // request push permissions, register categories, …
    }
}

@main
struct DemoApp: App {
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

Modules are resolved using Kahn’s algorithm:
- Missing dependencies throw an explicit `.missingDependency` error.
- Cycles throw `.cyclicDependency` with the unresolved keys.
- Configuration runs on the main actor and executes once per scene tree initialization.

## License

AppHooksUI is released under the MIT License. See [LICENSE](LICENSE) for details.
