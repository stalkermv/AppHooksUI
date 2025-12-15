@resultBuilder
public enum ApplicationModuleBuilder {

    public static func buildBlock(_ components: [ApplicationModule]...) -> [ApplicationModule] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: ApplicationModule) -> [ApplicationModule] {
        [expression]
    }

    public static func buildExpression(_ expression: [ApplicationModule]) -> [ApplicationModule] {
        expression
    }

    public static func buildExpression(_ expression: ApplicationModule?) -> [ApplicationModule] {
        expression.map { [$0] } ?? []
    }

    public static func buildOptional(_ component: [ApplicationModule]?) -> [ApplicationModule] {
        component ?? []
    }

    public static func buildEither(first component: [ApplicationModule]) -> [ApplicationModule] {
        component
    }

    public static func buildEither(second component: [ApplicationModule]) -> [ApplicationModule] {
        component
    }

    public static func buildArray(_ components: [[ApplicationModule]]) -> [ApplicationModule] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [ApplicationModule]) -> [ApplicationModule] {
        component
    }
}
