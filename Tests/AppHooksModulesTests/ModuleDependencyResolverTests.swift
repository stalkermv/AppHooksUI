import Testing
@testable import AppHooksModules

@Suite
struct ModuleDependencyResolverTests {

    @Test
    func resolvesDependenciesInDeclaredOrder() throws {
        let modules: [ApplicationModule] = [
            AnalyticsModule(),
            LoggingModule(),
            FeatureModule()
        ]

        let resolver = ModuleDependencyResolver(modules: modules)
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
        let resolver = ModuleDependencyResolver(modules: modules)

        do {
            _ = try resolver.resolve()
            Issue.record("Expected missingDependency error to be thrown")
        } catch let error as ModuleDependencyResolver.DependencyResolutionError {
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

        let resolver = ModuleDependencyResolver(modules: modules)

        do {
            _ = try resolver.resolve()
            Issue.record("Expected cyclicDependency error to be thrown")
        } catch let error as ModuleDependencyResolver.DependencyResolutionError {
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
}

private final class AnalyticsModule: ApplicationModule {
    func configure(application: UIApplication) throws {}
}

private final class LoggingModule: ApplicationModule {
    let dependencies = [AnalyticsModule.key]
    func configure(application: UIApplication) throws {}
}

private final class FeatureModule: ApplicationModule {
    let dependencies = [LoggingModule.key]
    func configure(application: UIApplication) throws {}
}

private final class BrokenModule: ApplicationModule {
    let dependencies = [ApplicationModuleKey(value: "GhostModule")]
    func configure(application: UIApplication) throws {}
}

private final class FirstModule: ApplicationModule {
    let dependencies = [SecondModule.key]
    func configure(application: UIApplication) throws {}
}

private final class SecondModule: ApplicationModule {
    let dependencies = [FirstModule.key]
    func configure(application: UIApplication) throws {}
}

