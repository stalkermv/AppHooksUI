import Testing
@testable import AppHooksModules

struct ModuleBootstrapBoundaryTests {
    @Test
    @MainActor
    func configurationFailureStopsLaterModulesWithoutRollingBackEarlierOnes() {
        let recorder = BootstrapRecorder()
        let first = RecordedModule("first", recorder: recorder)
        let failing = RecordedModule("failing", recorder: recorder, fails: true)
        let last = RecordedModule("last", recorder: recorder)
        let bootstrap = ApplicationModuleBootstrap(modules: [first, failing, last])
        #expect(throws: BootstrapFailure.self) {
            try bootstrap.configure(application: PlatformApplication.shared)
        }
        #expect(recorder.events == ["first", "failing"])
    }

    @Test
    @MainActor
    func bootstrapIsRepeatableRatherThanImplicitlyOnceOnly() throws {
        let recorder = BootstrapRecorder()
        let bootstrap = ApplicationModuleBootstrap(modules: [RecordedModule("first", recorder: recorder)])
        try bootstrap.configure(application: PlatformApplication.shared)
        try bootstrap.configure(application: PlatformApplication.shared)
        #expect(recorder.events == ["first", "first"])
    }

    @Test
    func eachResolveUsesOneFreshMetadataSnapshot() throws {
        let module = ChangingMetadataModule()
        let resolver = ApplicationModuleResolver(modules: [module])
        #expect(try resolver.resolve().count == 1)
        #expect(module.keyReads == 1)
        #expect(module.dependencyReads == 1)
        module.requiresMissingModule = true
        #expect(throws: ApplicationModuleResolutionError.missingDependency(
            dependent: ApplicationModuleKey(value: "changing"),
            missing: ApplicationModuleKey(value: "missing")
        )) {
            try resolver.resolve()
        }
        #expect(module.keyReads == 2)
        #expect(module.dependencyReads == 2)
    }
}
