//
//  OBJCPropertyMacro.swift
//
//
//  Created by Javier Segura Perez on 16/11/23.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct OBJCPropertyMacro: MemberAttributeMacro
{
    public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                                 attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
                                 providingAttributesFor member: some SwiftSyntax.DeclSyntaxProtocol,
                                 in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.AttributeSyntax] {
        
        #if os(Linux)
        return []
        #else
        return [ "objc" ]
        #endif
    }
}
