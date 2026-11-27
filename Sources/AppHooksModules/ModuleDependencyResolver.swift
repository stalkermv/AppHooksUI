/// Resolves application modules in deterministic topological order.
///
/// Each resolve snapshots keys and dependencies once. Initially ready modules
/// enter a FIFO queue in input order; newly ready modules append in edge order.
public struct ApplicationModuleResolver {
    private struct Registration {
        let module: any ApplicationModule
        let key: ApplicationModuleKey
        let dependencies: [ApplicationModuleKey]
    }

    private struct DependencyGraph {
        var adjacencyList: [ApplicationModuleKey: [ApplicationModuleKey]] = [:]
        var inDegree: [ApplicationModuleKey: Int] = [:]
    }

    private let modules: [ApplicationModule]

    public init(modules: [ApplicationModule]) {
        self.modules = modules
    }

    /// Resolves modules or throws a typed graph validation error.
    public func resolve() throws -> [ApplicationModule] {
        let registrations = modules.map {
            Registration(module: $0, key: $0.key, dependencies: $0.dependencies)
        }
        try validateUniqueKeys(registrations)
        let moduleMap = Dictionary(uniqueKeysWithValues: registrations.map { ($0.key, $0.module) })
        var graph = try makeGraph(registrations, moduleMap: moduleMap)
        let sortedKeys = try topologicalOrder(in: &graph, registrations: registrations)
        return sortedKeys.compactMap { moduleMap[$0] }
    }

    private func validateUniqueKeys(_ registrations: [Registration]) throws {
        var seenKeys = Set<ApplicationModuleKey>()
        for module in registrations {
            guard seenKeys.insert(module.key).inserted else {
                throw ApplicationModuleResolutionError.duplicateModule(module.key)
            }
        }
    }

    private func makeGraph(
        _ registrations: [Registration], moduleMap: [ApplicationModuleKey: ApplicationModule]
    ) throws -> DependencyGraph {
        var graph = DependencyGraph()
        for module in registrations {
            graph.adjacencyList[module.key] = []
            graph.inDegree[module.key] = 0
        }

        for module in registrations {
            var dependencies = Set<ApplicationModuleKey>()
            for dependency in module.dependencies {
                guard moduleMap[dependency] != nil else {
                    throw ApplicationModuleResolutionError.missingDependency(
                        dependent: module.key,
                        missing: dependency
                    )
                }

                guard dependencies.insert(dependency).inserted else {
                    throw ApplicationModuleResolutionError.duplicateDependency(
                        dependent: module.key,
                        dependency: dependency
                    )
                }

                graph.adjacencyList[dependency, default: []].append(module.key)
                graph.inDegree[module.key, default: 0] += 1
            }
        }

        return graph
    }

    private func topologicalOrder(
        in graph: inout DependencyGraph, registrations: [Registration]
    ) throws -> [ApplicationModuleKey] {
        // Never seed the queue from a dictionary. Dictionary iteration order
        // is an implementation detail and would make independent modules
        // start in a different order between runs.
        var queue = registrations.compactMap { module in
            graph.inDegree[module.key] == 0 ? module.key : nil
        }

        var sortedKeys: [ApplicationModuleKey] = []
        sortedKeys.reserveCapacity(modules.count)

        var index = 0
        while index < queue.count {
            let current = queue[index]
            index += 1
            sortedKeys.append(current)

            for neighbor in graph.adjacencyList[current, default: []] {
                guard let currentDegree = graph.inDegree[neighbor] else { continue }
                let nextDegree = currentDegree - 1
                graph.inDegree[neighbor] = nextDegree

                if nextDegree == 0 {
                    queue.append(neighbor)
                }
            }
        }

        if sortedKeys.count != modules.count {
            let unresolvedKeys: [ApplicationModuleKey] = registrations.compactMap { module in
                guard graph.inDegree[module.key, default: 0] > 0 else { return nil }
                return module.key
            }
            throw ApplicationModuleResolutionError.cyclicDependency(unresolvedKeys)
        }

        return sortedKeys
    }
}

/// Errors reported while validating an application-module graph.
public enum ApplicationModuleResolutionError: Error, Equatable, Sendable, CustomStringConvertible {
    case duplicateModule(ApplicationModuleKey)
    case missingDependency(dependent: ApplicationModuleKey, missing: ApplicationModuleKey)
    case duplicateDependency(dependent: ApplicationModuleKey, dependency: ApplicationModuleKey)
    case cyclicDependency([ApplicationModuleKey])

    public var description: String {
        switch self {
        case let .duplicateModule(key):
            return "Module key '\(key.value)' is registered more than once."
        case let .missingDependency(dependent, missing):
            return "Dependency '\(missing.value)' required by '\(dependent.value)' is not registered."
        case let .duplicateDependency(dependent, dependency):
            return "Module '\(dependent.value)' declares dependency '\(dependency.value)' more than once."
        case let .cyclicDependency(keys):
            let keyList = keys.map(\.value).joined(separator: ", ")
            return "Detected cyclic dependency between modules: [\(keyList)]."
        }
    }
}
