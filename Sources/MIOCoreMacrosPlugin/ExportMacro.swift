//
//  ExportMacro.swift
//  MIOCoreMacrosPlugin
//
//  @Export: puts the WebAssembly export of a plain Swift function next to it (see
//  MIOExportCore for the calling convention, and mio-wasm-bindings for the JS side).
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics
import MIOExportCore

public struct ExportMacro: PeerMacro {

    public static func expansion (
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let function = declaration.as( FunctionDeclSyntax.self ) else {
            throw ExportError( "@Export applies to functions" )
        }
        let exported = try ExportedFunction( function, attribute: node )
        return [ DeclSyntax( stringLiteral: exported.wasmWrapperSource ) ]
    }
}
