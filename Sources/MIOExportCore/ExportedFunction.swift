//
//  ExportedFunction.swift
//  MIOExportCore
//
//  The model of an `@Export` function, read from its declaration. The macro uses it to
//  write the WebAssembly wrapper and mio-wasm-bindings uses it to write the JavaScript /
//  TypeScript side, so both always agree on the calling convention (MIOCoreWasm's):
//
//    Swift type          wasm arguments              JavaScript
//    Int, Int32          i32                         number
//    Double, Float       f64 / f32                   number
//    Bool                i32 (1 / 0)                 boolean
//    String, String?     (pointer, length)           string (null → nil)
//    Data, [UInt8]       (pointer, length)           Uint8Array
//    any Codable T       (pointer, length) JSON      any (JSON.stringify)
//
//  Results: numbers and Bool as above; String / Data / [UInt8] / Encodable come back as an
//  MCWasm buffer (Encodable as JSON). A function that can fail (it throws or decodes a
//  JSON argument) records the error with MCWasm.fail and JS reads it with mio_take_error.
//

import SwiftSyntax

public enum ExportKind: Equatable, Sendable {
    case int, int32, double, float, bool
    case string, data, bytes
    /// Any other type, passed as JSON (Decodable arguments, Encodable results).
    case json( String )

    var isNumber: Bool {
        switch self { case .int, .int32, .double, .float, .bool: return true; default: return false }
    }
}

public struct ExportType: Equatable, Sendable {
    public var kind: ExportKind
    public var optional: Bool
}

public struct ExportParameter: Equatable, Sendable {
    /// The argument label in calls (nil for `_`).
    public var label: String?
    public var name: String
    public var type: ExportType
    /// The default value when it is a plain literal (true, 3, "x", nil), as written.
    public var defaultLiteral: String?
}

public struct ExportedFunction: Equatable, Sendable {
    public var swiftName: String
    /// The wasm export name: `@Export("dlr_sort")`, or the Swift name.
    public var symbol: String
    public var parameters: [ExportParameter]
    /// nil for Void.
    public var result: ExportType?
    public var `throws`: Bool
    /// The `///` documentation, without the slashes.
    public var documentation: [String]

    /// Throws or decodes JSON, so the wrapper needs a catch and JS an error check.
    public var canFail: Bool { `throws` || parameters.contains { if case .json = $0.type.kind { return true } else { return false } } }

    /// The Swift name of the generated wrapper (the macro introduces it as a prefixed peer).
    public static let wrapperPrefix = "_mio_export_"
    public var wrapperName: String { ExportedFunction.wrapperPrefix + swiftName }
}

public struct ExportError: Error, CustomStringConvertible, Sendable {
    public let message: String
    public init ( _ message: String ) { self.message = message }
    public var description: String { message }
}

// MARK: - Reading declarations

extension ExportedFunction {

    /// Reads `declaration`; `attribute` is its @Export attribute (for the symbol name).
    public init ( _ declaration: FunctionDeclSyntax, attribute: AttributeSyntax? ) throws {
        let name = declaration.name.text
        swiftName = name
        symbol = ExportedFunction.symbolArgument( attribute ) ?? name

        if declaration.genericParameterClause != nil {
            throw ExportError( "@Export functions cannot be generic" )
        }
        for modifier in declaration.modifiers {
            let m = modifier.name.text
            if m == "static" || m == "class" || m == "mutating" {
                throw ExportError( "@Export needs a global function; '\( name )' is a member" )
            }
        }
        let effects = declaration.signature.effectSpecifiers
        if effects?.asyncSpecifier != nil { throw ExportError( "@Export functions cannot be async" ) }
        `throws` = effects?.throwsSpecifier != nil

        parameters = try declaration.signature.parameterClause.parameters.map { p in
            if p.ellipsis != nil { throw ExportError( "@Export functions cannot take variadic parameters" ) }
            if let attributed = p.type.as( AttributedTypeSyntax.self ), attributed.specifier != nil {
                throw ExportError( "@Export parameters cannot be inout / borrowing / consuming" )
            }
            let first = p.firstName.text
            let local = p.secondName?.text ?? first
            return ExportParameter( label: first == "_" ? nil : first
                                  , name: local
                                  , type: try ExportedFunction.exportType( p.type, result: false )
                                  , defaultLiteral: p.defaultValue.flatMap { ExportedFunction.literal( $0.value ) } )
        }

        if let r = declaration.signature.returnClause?.type, !ExportedFunction.isVoid( r ) {
            result = try ExportedFunction.exportType( r, result: true )
        } else {
            result = nil
        }

        documentation = ExportedFunction.documentation( declaration.leadingTrivia )
    }

    static func symbolArgument ( _ attribute: AttributeSyntax? ) -> String? {
        guard let arguments = attribute?.arguments?.as( LabeledExprListSyntax.self ),
              let first = arguments.first, first.label == nil,
              let literal = first.expression.as( StringLiteralExprSyntax.self ) else { return nil }
        let text = literal.segments.compactMap { $0.as( StringSegmentSyntax.self )?.content.text }.joined( )
        return text.isEmpty ? nil : text
    }

    static func isVoid ( _ type: TypeSyntax ) -> Bool {
        let t = type.trimmedDescription
        return t == "Void" || t == "()" || t == "Swift.Void"
    }

    static func exportType ( _ type: TypeSyntax, result: Bool ) throws -> ExportType {
        var wrapped = type
        var optional = false
        if let o = type.as( OptionalTypeSyntax.self ) {
            wrapped = o.wrappedType
            optional = true
        } else if let o = type.as( ImplicitlyUnwrappedOptionalTypeSyntax.self ) {
            wrapped = o.wrappedType
            optional = true
        } else if let g = type.as( IdentifierTypeSyntax.self ), g.name.text == "Optional",
                  let argument = g.genericArgumentClause?.arguments.first {
            wrapped = argument.argument
            optional = true
        }
        let text = wrapped.trimmedDescription
        let kind: ExportKind
        switch text.hasPrefix( "Swift." ) ? String( text.dropFirst( 6 ) ) : text {
        case "Int": kind = .int
        case "Int32": kind = .int32
        case "Double": kind = .double
        case "Float": kind = .float
        case "Bool": kind = .bool
        case "String": kind = .string
        case "Data", "Foundation.Data": kind = .data
        case "[UInt8]", "Array<UInt8>": kind = .bytes
        default: kind = .json( text )
        }
        if optional && kind.isNumber {
            throw ExportError( "@Export cannot pass an optional \( text ); use a non-optional value or a Codable type" )
        }
        return ExportType( kind: kind, optional: optional )
    }

    /// true / false / nil / numbers / plain strings, which JS can use as defaults as written.
    static func literal ( _ expression: ExprSyntax ) -> String? {
        if expression.is( BooleanLiteralExprSyntax.self ) || expression.is( IntegerLiteralExprSyntax.self )
            || expression.is( FloatLiteralExprSyntax.self ) {
            return expression.trimmedDescription
        }
        if expression.is( NilLiteralExprSyntax.self ) { return "null" }
        if let p = expression.as( PrefixOperatorExprSyntax.self ), p.operator.text == "-",
           p.expression.is( IntegerLiteralExprSyntax.self ) || p.expression.is( FloatLiteralExprSyntax.self ) {
            return expression.trimmedDescription
        }
        if let s = expression.as( StringLiteralExprSyntax.self ), s.openingPounds == nil,
           s.segments.allSatisfy( { $0.is( StringSegmentSyntax.self ) } ) {
            return expression.trimmedDescription
        }
        return nil
    }

    static func documentation ( _ trivia: Trivia ) -> [String] {
        var lines: [String] = []
        for piece in trivia {
            switch piece {
            case .docLineComment( let text ):
                var line = text.dropFirst( 3 )
                if line.first == " " { line = line.dropFirst( ) }
                lines.append( String( line ) )
            case .docBlockComment( let text ):
                let body = text.dropFirst( 3 ).dropLast( 2 )
                lines += body.split( separator: "\n", omittingEmptySubsequences: false ).map {
                    var l = $0.drop( while: { $0 == " " || $0 == "\t" } )
                    if l.first == "*" { l = l.dropFirst( ); if l.first == " " { l = l.dropFirst( ) } }
                    return String( l )
                }.filter { !$0.isEmpty }
            default: break
            }
        }
        return lines
    }
}
