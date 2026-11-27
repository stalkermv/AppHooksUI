/// Configures a validated module graph for a concrete application instance.
///
/// Configuration is performed on the main actor in resolver order. A bootstrap
/// value represents one configuration request; modules should be idempotent if
/// the surrounding SwiftUI scene is recreated.
public struct ApplicationModuleBootstrap {
    private let resolver: ApplicationModuleResolver

    public init(modules: [ApplicationModule]) {
        resolver = ApplicationModuleResolver(modules: modules)
    }

    /// Resolves and configures every module.
    @MainActor
    public func configure(application: PlatformApplication) throws {
        for module in try resolver.resolve() {
            try module.configure(application: application)
        }
    }
}
