# ``AppHooksModules``

Describe startup work as modules with dependencies, and configure them in order.

## Overview

Each module does one piece of startup work and lists the modules it depends on. The package configures them so that every module runs after its dependencies.

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

`.modules { }` cannot return an error, so an invalid module graph or a module that throws stops the app. To handle errors yourself, use ``ApplicationModuleBootstrap``:

```swift
let bootstrap = ApplicationModuleBootstrap(modules: [AnalyticsModule(), PushModule()])
try bootstrap.configure(application: PlatformApplication.shared)
```

To check a graph without configuring anything, call ``ApplicationModuleResolver/resolve()``. Modules that do not depend on each other keep the order you listed them in.

SwiftUI can create scene values more than once, so write ``ApplicationModule/configure(application:)`` so that running it again is harmless.

## Topics

### Defining modules

- ``ApplicationModule``
- ``ApplicationModuleKey``
- ``ApplicationModuleBuilder``

### Configuring modules

- ``ApplicationModuleBootstrap``
- ``ApplicationModuleResolver``
- ``ApplicationModuleResolutionError``

### Platform types

- ``PlatformApplication``
