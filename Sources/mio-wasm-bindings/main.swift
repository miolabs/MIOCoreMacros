//
//  mio-wasm-bindings
//
//  Writes the JavaScript class (and its .d.ts) for the @Export functions of Swift sources:
//
//    mio-wasm-bindings --class DLReportKitWasm --output js/DLReportKitWasm.js Sources/DLReportKitWasm
//
//  Options: --class <name> (required), --output <file.js> (required; the .d.ts goes next to
//  it), --miowasm <import path> (default ./miowasm.js). Inputs: .swift files or folders.
//

import Foundation
import MIOExportCore

func fail ( _ message: String ) -> Never {
    FileHandle.standardError.write( Data( ( "mio-wasm-bindings: " + message + "\n" ).utf8 ) )
    exit( 1 )
}

var className: String?
var output: String?
var miowasm = "./miowasm.js"
var inputs: [String] = []

var arguments = CommandLine.arguments.dropFirst( ).makeIterator( )
while let a = arguments.next( ) {
    switch a {
    case "--class": className = arguments.next( )
    case "--output": output = arguments.next( )
    case "--miowasm": miowasm = arguments.next( ) ?? miowasm
    case "-h", "--help":
        print( "usage: mio-wasm-bindings --class <Name> --output <file.js> [--miowasm <path>] <sources…>" )
        exit( 0 )
    default: inputs.append( a )
    }
}
guard let className = className, let output = output, !inputs.isEmpty else {
    fail( "usage: mio-wasm-bindings --class <Name> --output <file.js> [--miowasm <path>] <sources…>" )
}

let fm = FileManager.default
var files: [String] = []
for input in inputs {
    var isDirectory: ObjCBool = false
    guard fm.fileExists( atPath: input, isDirectory: &isDirectory ) else { fail( "no such file: \( input )" ) }
    if isDirectory.boolValue {
        let found = ( fm.enumerator( atPath: input )?.compactMap { $0 as? String } ?? [] )
            .filter { $0.hasSuffix( ".swift" ) }.sorted( )
        files += found.map { ( input as NSString ).appendingPathComponent( $0 ) }
    } else {
        files.append( input )
    }
}

var functions: [ExportedFunction] = []
do {
    for file in files {
        functions += try ExportScanner.scan( source: try String( contentsOfFile: file, encoding: .utf8 ), file: file )
    }
} catch {
    fail( "\( error )" )
}
if functions.isEmpty { fail( "no @Export functions found" ) }
var symbols = Set<String>()
for f in functions where !symbols.insert( f.symbol ).inserted { fail( "export name \( f.symbol ) is used twice" ) }

let bindings = JSBindings( className: className, miowasmPath: miowasm, functions: functions )
let declarations = ( output.hasSuffix( ".js" ) ? String( output.dropLast( 3 ) ) : output ) + ".d.ts"
do {
    try fm.createDirectory( atPath: ( output as NSString ).deletingLastPathComponent.isEmpty ? "." : ( output as NSString ).deletingLastPathComponent, withIntermediateDirectories: true )
    try bindings.javaScript.write( toFile: output, atomically: true, encoding: .utf8 )
    try bindings.typeScript.write( toFile: declarations, atomically: true, encoding: .utf8 )
} catch {
    fail( "\( error )" )
}
print( "mio-wasm-bindings: \( functions.count ) functions → \( output ), \( declarations )" )
