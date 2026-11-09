// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "MIOCoreMacros",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MIOCoreMacros",
            targets: ["MIOCoreMacros"]
        ),
        // Writes the JavaScript / TypeScript side of @Export functions
        .executable( name: "mio-wasm-bindings", targets: [ "mio-wasm-bindings" ] ),
        .plugin( name: "WasmBindings", targets: [ "WasmBindings" ] ),
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
        // The @Export model, shared by the macro (Swift wrapper) and mio-wasm-bindings (JS)
        .target(
            name: "MIOExportCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .executableTarget( name: "mio-wasm-bindings", dependencies: [ "MIOExportCore" ] ),
        .plugin(
            name: "WasmBindings",
            capability: .command(
                intent: .custom( verb: "wasm-bindings", description: "Write the JavaScript / TypeScript bindings of @Export functions" ),
                permissions: [ .writeToPackageDirectory( reason: "Writes the generated JavaScript bindings" ) ]
            ),
            dependencies: [ "mio-wasm-bindings" ]
        ),
        .macro(
            name: "MIOCoreMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "Shared",
                "MIOExportCore"
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(name: "MIOCoreMacros", dependencies: ["MIOCoreMacrosPlugin", "Shared"]),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "MIOCoreMacrosTests",
            dependencies: [
                "MIOCoreMacrosPlugin",
                "MIOExportCore",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
