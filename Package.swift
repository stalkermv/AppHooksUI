// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AppHooksUI",
    // The delegate and notification APIs this package wraps exist only on
    // iOS and macOS, so other platforms are not declared.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(
            name: "AppHooksUI",
            targets: ["AppHooksUI"]
        ),
        .library(
            name: "AppHooksModules",
            targets: ["AppHooksModules"]
        ),
    ],
    targets: [
        .target(name: "AppHooksUI"),
        .target(name: "AppHooksModules"),
        .testTarget(
            name: "AppHooksUITests",
            dependencies: ["AppHooksUI"]
        ),
        .testTarget(
            name: "AppHooksModulesTests",
            dependencies: ["AppHooksModules"]
        ),
    ]
)
