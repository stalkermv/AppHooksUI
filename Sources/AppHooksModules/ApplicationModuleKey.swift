/// A stable identifier for a concrete ``ApplicationModule`` type.
public struct ApplicationModuleKey: Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let value: String

    /// Creates a key from an explicitly chosen identifier.
    ///
    /// Use an explicit value for identifiers that must remain stable across
    /// refactors or are shared by modules in different packages.
    public init(value: String) {
        self.value = value
    }

    public init<Module: ApplicationModule>(module: Module.Type) {
        // Keep module qualification in the default key. The short spelling
        // can collide for nested types with the same name.
        self.init(value: String(reflecting: Module.self))
    }

    public var description: String { value }
    public var debugDescription: String { "ApplicationModuleKey(\(value))" }
}
