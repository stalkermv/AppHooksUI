# ``AppHooksUI``

Handle application delegate callbacks in SwiftUI with view modifiers.

## Overview

Install ``ApplicationDelegate`` with the platform delegate adaptor. SwiftUI puts it into the environment, and the notification modifiers read it from there.

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

Then attach the modifiers to the views that need them:

```swift
struct ContentView: View {
    var body: some View {
        Text("Hello")
            .onUserNotificationResponse { response in
                print(response.notification.request.identifier)
            }
            .userNotificationPresentationOptions([.banner, .sound])
            #if os(iOS)
            .onRegisterDeviceToken { result in
                print(result)
            }
            .onReceiveRemoteNotification { notification in
                print(notification.userInfo)
                return .newData
            }
            #endif
    }
}
```

The modifiers are extensions on `View`:

- `onUserNotificationResponse(perform:)`: the user tapped a notification or one of its actions.
- `userNotificationPresentationOptions(_:)`: how a notification is shown while the app is in the foreground, as fixed options or an async closure.
- `onRegisterDeviceToken(_:)` (iOS): the APNs device token, or the registration error.
- `onReceiveRemoteNotification(_:)` (iOS): a background push. Return the result to pass back to the system.

A device token or notification response that arrives before any view is listening is kept and delivered once to the first view that subscribes. When several views set a presentation policy or handle background pushes, the most recently shown view wins.

``ApplicationDelegate`` sets itself as `UNUserNotificationCenter.current().delegate` at launch. If your app sets its own notification center delegate, the response and presentation modifiers are not called.

For lifecycle state, use SwiftUI's `scenePhase` with `onChange(of:)`.

## Topics

### Delegate

- ``ApplicationDelegate``

### Platform types

- ``PlatformApplication``
- ``AppDelegateBase``

The iOS-only types `PushNotification`, `RemoteNotificationResult` and `LaunchOptionsKey` are listed in the iOS documentation.
