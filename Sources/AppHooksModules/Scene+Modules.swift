import SwiftUI

extension Scene {
    /// Configures an ordered list of ``ApplicationModule`` instances before the
    /// scene hierarchy is rendered.
    ///
    /// The modifier is fail-fast: malformed dependencies or a throwing module
    /// are startup failures, not partially configured applications hidden by a
    /// debug-only log. SwiftUI may recreate scene values, so modules should be
    /// idempotent.
    @MainActor public func modules(
        @ApplicationModuleBuilder modules: () -> [ApplicationModule]
    ) -> some Scene {
        ApplicationModuleScene(content: self, modules: modules())
    }
}

@MainActor private struct ApplicationModuleScene<Content: Scene>: Scene {
    private let content: Content

    init(content: Content, modules: [ApplicationModule]) {
        self.content = content

        guard !modules.isEmpty else { return }

        do {
            try ApplicationModuleBootstrap(modules: modules)
                .configure(application: PlatformApplication.shared)
        } catch {
            preconditionFailure("AppHooksModules failed to configure modules: \(error)")
        }
    }

    var body: some Scene {
        content
    }
}
