import AppHooksModules

final class AnalyticsModule: ApplicationModule {
    func configure(application: PlatformApplication) throws {}
}

final class LoggingModule: ApplicationModule {
    let dependencies = [AnalyticsModule.key]

    func configure(application: PlatformApplication) throws {}
}

final class FeatureModule: ApplicationModule {
    let dependencies = [LoggingModule.key]

    func configure(application: PlatformApplication) throws {}
}

final class BrokenModule: ApplicationModule {
    let dependencies = [ApplicationModuleKey(value: "GhostModule")]

    func configure(application: PlatformApplication) throws {}
}

final class FirstModule: ApplicationModule {
    let dependencies = [SecondModule.key]

    func configure(application: PlatformApplication) throws {}
}

final class SecondModule: ApplicationModule {
    let dependencies = [FirstModule.key]

    func configure(application: PlatformApplication) throws {}
}

final class DuplicateModule: ApplicationModule {
    static let identifier = ApplicationModuleKey(value: "duplicate")

    var key: ApplicationModuleKey { Self.identifier }

    func configure(application: PlatformApplication) throws {}
}

final class IndependentA: ApplicationModule {
    static let identifier = ApplicationModuleKey(value: "independent.a")

    var key: ApplicationModuleKey { Self.identifier }

    func configure(application: PlatformApplication) throws {}
}

final class IndependentB: ApplicationModule {
    static let identifier = ApplicationModuleKey(value: "independent.b")

    var key: ApplicationModuleKey { Self.identifier }

    func configure(application: PlatformApplication) throws {}
}

final class DuplicateDependencyModule: ApplicationModule {
    let dependencies = [AnalyticsModule.key, AnalyticsModule.key]

    func configure(application: PlatformApplication) throws {}
}

enum NamespaceA {
    final class StartupModule: ApplicationModule {
        func configure(application: PlatformApplication) throws {}
    }
}

enum NamespaceB {
    final class StartupModule: ApplicationModule {
        func configure(application: PlatformApplication) throws {}
    }
}

final class StaticIdentifierModule: ApplicationModule {
    static let key = ApplicationModuleKey(value: "static.identifier")

    func configure(application: PlatformApplication) throws {}
}
