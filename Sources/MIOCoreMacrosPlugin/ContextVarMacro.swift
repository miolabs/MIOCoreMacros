//
//  ContextVarMacro.swift
//
//
//  Created by Javier Segura Perez on 16/11/23.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ContextVarAccessor : OptionSet
{
    public let rawValue:UInt16
    
    public static let read = ContextVarAccessor(rawValue: 1 << 0 )
    public static let write = ContextVarAccessor(rawValue: 1 << 1 )
    
    public static let readOnly: ContextVarAccessor = ContextVarAccessor(rawValue: 1 << 0 )
    public static let readAndWrite:ContextVarAccessor = [ .read, .write ]
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    public init( string: String ) {
        switch string{
        case "readOnly": self.rawValue = ContextVarAccessor.readOnly.rawValue
        default: self.rawValue = ContextVarAccessor.readAndWrite.rawValue
        }
    }

}

public struct ContextVarMacro: AccessorMacro
{
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingAccessorsOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.AccessorDeclSyntax] {
        
        var accessor_type = ContextVarAccessor.readAndWrite
        
        if let arguments = node.arguments?.as( LabeledExprListSyntax.self ) {
            for arg in arguments {
                if arg.label?.text == "accessor" {
                    if let exp = arg.expression.as(MemberAccessExprSyntax.self) {
                        if let decl = exp.declName.as( DeclReferenceExprSyntax.self) {
                            accessor_type = ContextVarAccessor( string: decl.baseName.text )
                        }
                    }
                }
            }
        }
        
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else { return [] }
        guard let binding = varDecl.bindings.first else { return [] }
        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else { return [] }
        guard let type = binding.typeAnnotation?.type else { return [] }

        let key = "_\(identifier.text.lowercased())_key_"
        
        var get_str:SwiftSyntax.AccessorDeclSyntax
        
        if let optional = type.as(OptionalTypeSyntax.self) {
            get_str =
               """
               get {
                  return globals[ \(literal: key) ] as? \(optional.wrappedType)
               }
               """
        }
        else {
            get_str =
               """
               get {
                  var v = globals[ \(literal: key) ] as? \(type)
                  if v == nil {
                      v = \(type)()
                      globals[ \(literal: key) ] = v
                  }
                  return v!
               }
               """
        }
        
        let set_str:SwiftSyntax.AccessorDeclSyntax =
            """
            set {
               globals[ \(literal: key) ] = newValue
            }
            """
        
        if !accessor_type.contains( .write ) {
            return [ get_str ]
        }
        else {
            return [ get_str, set_str ]
        }
    }
}
