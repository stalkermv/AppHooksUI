/// A stable identifier for a concrete ``ApplicationModule`` type.
public struct ApplicationModuleKey: Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let value: String

    public init(value: String) {
        self.value = value
    }

    public init<Module: ApplicationModule>(module: Module.Type) {
        self.init(value: String(describing: Module.self))
    }

    public var description: String { value }
    public var debugDescription: String { "ApplicationModuleKey(\(value))" }
}
