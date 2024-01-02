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

public struct ContextVarMacro: AccessorMacro
{
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingAccessorsOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.AccessorDeclSyntax] {
        
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
        
        return [
            get_str,
            """
            set {
               globals[ \(literal: key) ] = newValue
            }
            """
        ]

    }
}
