import SwiftUI

/// Describes a unit of application configuration that can be wired into a SwiftUI
/// scene via the `Scene.modules` modifier.
public protocol ApplicationModule {
    /// A list of dependency keys that must be configured before this module.
    var dependencies: [ApplicationModuleKey] { get }

    /// Performs the configuration work. The `application` argument resolves to
    /// the current platform-specific application instance (`UIApplication`,
    /// `NSApplication`, `WKExtension`, …).
    @MainActor func configure(application: UIApplication) throws
}

public extension ApplicationModule {
    var dependencies: [ApplicationModuleKey] { [] }

    /// A stable identifier for the module type.
    static var key: ApplicationModuleKey {
        ApplicationModuleKey(module: Self.self)
    }

    /// Convenience instance-level access to ``key``.
    var key: ApplicationModuleKey {
        Self.key
    }
}
