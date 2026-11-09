//
//  WasmBindings command plugin
//
//    swift package --allow-writing-to-package-directory wasm-bindings \
//        --target DLReportKitWasm --class DLReportKitWasm --output js/DLReportKitWasm.js
//
//  Runs mio-wasm-bindings over the target's sources; --output is relative to the package.
//

import PackagePlugin
import Foundation

@main
struct WasmBindings: CommandPlugin {

    func performCommand ( context: PluginContext, arguments: [String] ) async throws {
        var extractor = ArgumentExtractor( arguments )
        let targets = extractor.extractOption( named: "target" )
        guard let className = extractor.extractOption( named: "class" ).first,
              let output = extractor.extractOption( named: "output" ).first,
              !targets.isEmpty else {
            throw PluginError( "usage: wasm-bindings --target <Target> --class <Name> --output <file.js> [--miowasm <path>]" )
        }
        let miowasm = extractor.extractOption( named: "miowasm" ).first

        var sources: [String] = []
        for target in try context.package.targets( named: targets ) {
            guard let module = target as? SourceModuleTarget else { continue }
            sources += module.sourceFiles( withSuffix: "swift" ).map { $0.path.string }
        }
        let tool = try context.tool( named: "mio-wasm-bindings" )
        var args = [ "--class", className, "--output", context.package.directory.appending( output ).string ]
        if let m = miowasm { args += [ "--miowasm", m ] }
        let process = Process( )
        process.executableURL = URL( fileURLWithPath: tool.path.string )
        process.arguments = args + sources
        try process.run( )
        process.waitUntilExit( )
        if process.terminationStatus != 0 { throw PluginError( "mio-wasm-bindings failed" ) }
    }
}

struct PluginError: Error, CustomStringConvertible {
    let description: String
    init ( _ d: String ) { description = d }
}
