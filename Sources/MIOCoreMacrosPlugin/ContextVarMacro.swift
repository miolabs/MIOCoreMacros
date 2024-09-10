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

import Shared

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
