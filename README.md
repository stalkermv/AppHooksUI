# AppHooksUI

AppHooksUI is a Swift package that provides a collection of reusable SwiftUI components designed to streamline the implementation of application lifecycle hooks and UI interactions in your iOS projects.

## Features
- Lifecycle Hooks Integration: Simplify the management of application lifecycle events within SwiftUI views.
- Reusable Components: A set of SwiftUI views and modifiers to handle common UI patterns efficiently.
- Modular Design: Each component is self-contained, promoting clean and maintainable code.
- Swift Package Manager Support: Easily integrate into your projects using Swift Package Manager.

## Installation

You can add AppHooksUI to your project using Swift Package Manager:
1. In Xcode, go to File > Add Packages…
2. Enter the repository URL: `https://github.com/stalkermv/AppHooksUI`
3. Select the development branch.

Alternatively, add it directly to your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/stalkermv/AppHooksUI.git", branch: "development")
]
```

## Usage

Import AppHooksUI in your SwiftUI files:

```swift
import AppHooksUI
```

Then, utilize the provided components as needed. For example:

```swift
struct ContentView: View {
    var body: some View {
        Text("Hello, App Hooks!")
         .onUserNotificationResponse { response in
             // Handle the notification response
             print("User responded to notification: \(response.notification)")
         }
    }
}
```

## License

AppHooksUI is released under the MIT License. See LICENSE for details.
