/// Describes a unit of application configuration that can be wired into a SwiftUI
/// scene via the `Scene.modules` modifier.
public protocol ApplicationModule {
    /// The type-level key used by dependency declarations.
    static var key: ApplicationModuleKey { get }

    /// The key used to identify this module and its dependency edges.
    var key: ApplicationModuleKey { get }

    /// A list of dependency keys that must be configured before this module.
    var dependencies: [ApplicationModuleKey] { get }

    /// Performs the configuration work. The `application` argument is the
    /// caller-supplied platform application instance (`UIApplication` on iOS or
    /// `NSApplication` on macOS).
    @MainActor func configure(application: PlatformApplication) throws
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
