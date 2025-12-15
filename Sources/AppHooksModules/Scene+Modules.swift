import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(watchOS)
import WatchKit
#endif

extension Scene {
    /// Configures an ordered list of ``ApplicationModule`` instances before the
    /// scene hierarchy is rendered.
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

        do {
            try ApplicationModuleScene.configureModules(modules)
        } catch {
            #if DEBUG
            print("AppHooksModules: failed to configure modules: \(error)")
            #endif
        }
    }

    var body: some Scene {
        content
    }

    private static func configureModules(_ modules: [ApplicationModule]) throws {
        guard !modules.isEmpty else { return }

        let resolver = ModuleDependencyResolver(modules: modules)
        let sortedModules = try resolver.resolve()

        guard let application = sharedApplication else {
            #if DEBUG
            print("AppHooksModules: unable to access shared application instance for this platform.")
            #endif
            return
        }

        for module in sortedModules {
            try module.configure(application: application)
        }
    }
}

@MainActor
private var sharedApplication: UIApplication? {
    #if os(iOS) || os(tvOS)
    UIApplication.shared
    #elseif os(macOS)
    NSApplication.shared
    #elseif os(watchOS)
    WKExtension.shared()
    #else
    nil
    #endif
}
