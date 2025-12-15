struct ModuleDependencyResolver {
    private let modules: [ApplicationModule]
    private let moduleMap: [ApplicationModuleKey: ApplicationModule]

    init(modules: [ApplicationModule]) {
        self.modules = modules
        self.moduleMap = Dictionary(uniqueKeysWithValues: modules.map { ($0.key, $0) })
    }

    func resolve() throws -> [ApplicationModule] {
        var adjacencyList: [ApplicationModuleKey: [ApplicationModuleKey]] = [:]
        var inDegree: [ApplicationModuleKey: Int] = [:]

        for module in modules {
            adjacencyList[module.key] = []
            inDegree[module.key] = 0
        }

        for module in modules {
            for dependency in module.dependencies {
                guard moduleMap[dependency] != nil else {
                    throw DependencyResolutionError.missingDependency(
                        dependent: module.key,
                        missing: dependency
                    )
                }

                adjacencyList[dependency, default: []].append(module.key)
                inDegree[module.key, default: 0] += 1
            }
        }

        var queue: [ApplicationModuleKey] = inDegree
            .filter { $0.value == 0 }
            .map(\.key)

        var sortedKeys: [ApplicationModuleKey] = []
        sortedKeys.reserveCapacity(modules.count)

        var index = 0
        while index < queue.count {
            let current = queue[index]
            index += 1
            sortedKeys.append(current)

            for neighbor in adjacencyList[current, default: []] {
                guard let currentDegree = inDegree[neighbor] else { continue }
                let nextDegree = currentDegree - 1
                inDegree[neighbor] = nextDegree

                if nextDegree == 0 {
                    queue.append(neighbor)
                }
            }
        }

        if sortedKeys.count != modules.count {
            let unresolvedKeys = inDegree
                .filter { $0.value > 0 }
                .map(\.key)

            throw DependencyResolutionError.cyclicDependency(unresolvedKeys)
        }

        return sortedKeys.compactMap { moduleMap[$0] }
    }

    enum DependencyResolutionError: Error, Equatable, CustomStringConvertible {
        case missingDependency(dependent: ApplicationModuleKey, missing: ApplicationModuleKey)
        case cyclicDependency([ApplicationModuleKey])

        var description: String {
            switch self {
            case let .missingDependency(dependent, missing):
                return "Dependency '\(missing.value)' required by '\(dependent.value)' is not registered."
            case let .cyclicDependency(keys):
                let keyList = keys.map(\.value).joined(separator: ", ")
                return "Detected cyclic dependency between modules: [\(keyList)]."
            }
        }
    }
}
