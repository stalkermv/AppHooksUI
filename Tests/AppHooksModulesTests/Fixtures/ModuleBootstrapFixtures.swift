import AppHooksModules

struct BootstrapFailure: Error {}

@MainActor
final class BootstrapRecorder {
    var events: [String] = []
}

struct RecordedModule: ApplicationModule {
    let key: ApplicationModuleKey
    let recorder: BootstrapRecorder
    let fails: Bool

    init(_ key: String, recorder: BootstrapRecorder, fails: Bool = false) {
        self.key = ApplicationModuleKey(value: key)
        self.recorder = recorder
        self.fails = fails
    }

    @MainActor
    func configure(application: PlatformApplication) throws {
        recorder.events.append(key.value)
        if fails { throw BootstrapFailure() }
    }
}

final class ChangingMetadataModule: ApplicationModule {
    var keyReads = 0
    var dependencyReads = 0
    var requiresMissingModule = false

    var key: ApplicationModuleKey {
        keyReads += 1
        return ApplicationModuleKey(value: "changing")
    }

    var dependencies: [ApplicationModuleKey] {
        dependencyReads += 1
        return requiresMissingModule ? [ApplicationModuleKey(value: "missing")] : []
    }

    func configure(application: PlatformApplication) throws {}
}

@MainActor
final class ConfigurationRecorder {
    var events: [String] = []
}

final class BootstrapFirst: ApplicationModule {
    static let key = ApplicationModuleKey(value: "bootstrap.first")
    let recorder: ConfigurationRecorder

    init(recorder: ConfigurationRecorder) {
        self.recorder = recorder
    }

    @MainActor
    func configure(application: PlatformApplication) throws {
        recorder.events.append(Self.key.value)
    }
}

final class BootstrapSecond: ApplicationModule {
    static let key = ApplicationModuleKey(value: "bootstrap.second")
    let dependencies = [BootstrapFirst.key]
    let recorder: ConfigurationRecorder

    init(recorder: ConfigurationRecorder) {
        self.recorder = recorder
    }

    @MainActor
    func configure(application: PlatformApplication) throws {
        recorder.events.append(Self.key.value)
    }
}
