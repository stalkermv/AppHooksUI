import Testing
@testable import AppHooksModules

struct ModuleDependencyResolverTests {

    @Test
    func resolvesDependenciesInDeclaredOrder() throws {
        let modules: [ApplicationModule] = [
            AnalyticsModule(),
            LoggingModule(),
            FeatureModule()
        ]

        let resolver = ApplicationModuleResolver(modules: modules)
        let resolvedKeys = try resolver.resolve().map(\.key)

        #expect(resolvedKeys == [
            AnalyticsModule.key,
            LoggingModule.key,
            FeatureModule.key
        ])
    }

    @Test
    func throwsWhenDependencyIsMissing() {
        let modules: [ApplicationModule] = [BrokenModule()]
        let resolver = ApplicationModuleResolver(modules: modules)

        do {
            _ = try resolver.resolve()
            Issue.record("Expected missingDependency error to be thrown")
        } catch let error as ApplicationModuleResolutionError {
            guard case let .missingDependency(dependent, missing) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }

            #expect(dependent == BrokenModule.key)
            #expect(missing.value == "GhostModule")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func throwsWhenCycleIsDetected() {
        let modules: [ApplicationModule] = [
            FirstModule(),
            SecondModule()
        ]

        let resolver = ApplicationModuleResolver(modules: modules)

        do {
            _ = try resolver.resolve()
            Issue.record("Expected cyclicDependency error to be thrown")
        } catch let error as ApplicationModuleResolutionError {
            guard case let .cyclicDependency(keys) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }

            let unresolved = Set(keys)
            #expect(unresolved.contains(FirstModule.key))
            #expect(unresolved.contains(SecondModule.key))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func preservesInputOrderForIndependentModules() throws {
        let modules: [ApplicationModule] = [
            IndependentB(),
            IndependentA()
        ]

        let resolved = try ApplicationModuleResolver(modules: modules).resolve()
        #expect(resolved.map(\.key) == [
            IndependentB.identifier,
            IndependentA.identifier
        ])
    }

    @Test
    func throwsForDuplicateModuleKey() {
        let resolver = ApplicationModuleResolver(modules: [DuplicateModule(), DuplicateModule()])

        do {
            _ = try resolver.resolve()
            Issue.record("Expected duplicateModule error to be thrown")
        } catch let error as ApplicationModuleResolutionError {
            #expect(error == .duplicateModule(DuplicateModule.identifier))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func reportsDuplicateDependencies() {
        let resolver = ApplicationModuleResolver(modules: [AnalyticsModule(), DuplicateDependencyModule()])

        do {
            _ = try resolver.resolve()
            Issue.record("Expected duplicateDependency error to be thrown")
        } catch let error as ApplicationModuleResolutionError {
            #expect(error == .duplicateDependency(
                dependent: DuplicateDependencyModule.key,
                dependency: AnalyticsModule.key
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func defaultKeysRetainTypeQualification() {
        #expect(NamespaceA.StartupModule.key != NamespaceB.StartupModule.key)
    }

    @Test
    func staticKeyCanOverrideTheDefaultIdentifier() throws {
        let resolved = try ApplicationModuleResolver(modules: [StaticIdentifierModule()]).resolve()
        let first = try #require(resolved.first)
        #expect(first.key == StaticIdentifierModule.key)
    }

    @Test
    @MainActor
    func bootstrapConfiguresModulesInResolvedOrder() throws {
        let recorder = ConfigurationRecorder()
        let modules: [ApplicationModule] = [
            BootstrapSecond(recorder: recorder),
            BootstrapFirst(recorder: recorder)
        ]

        try ApplicationModuleBootstrap(modules: modules).configure(application: PlatformApplication.shared)
        #expect(recorder.events == [BootstrapFirst.key.value, BootstrapSecond.key.value])
    }

    @Test
    func resultBuilderKeepsTrueBranchOrder() {
        let modules = makeModules(includeLogging: true)

        #expect(modules.map(\.key) == [
            AnalyticsModule.key,
            LoggingModule.key,
            FeatureModule.key
        ])
    }

    @Test
    func resultBuilderDropsTheFalseBranch() {
        let modules = makeModules(includeLogging: false)

        #expect(modules.map(\.key) == [
            AnalyticsModule.key,
            FeatureModule.key
        ])
    }
}

@ApplicationModuleBuilder
private func makeModules(includeLogging: Bool) -> [ApplicationModule] {
    AnalyticsModule()
    if includeLogging {
        [LoggingModule()]
    }
    Optional<FeatureModule>.none
    [] as [ApplicationModule]
    for module in [FeatureModule()] {
        module
    }
}
