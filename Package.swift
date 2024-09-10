// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "MIOCoreMacros",
    platforms: [.iOS(.v12), .macOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MIOCoreMacros",
            targets: ["MIOCoreMacros"]
        ),
    ],
    dependencies: [
        // Depend on the Swift 5.9 release of SwiftSyntax
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .target(name: "Shared"),
        .macro(
            name: "MIOCoreMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "Shared"
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(name: "MIOCoreMacros", dependencies: ["MIOCoreMacrosPlugin", "Shared"]),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "MIOCoreMacrosTests",
            dependencies: [
                "MIOCoreMacrosPlugin",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
