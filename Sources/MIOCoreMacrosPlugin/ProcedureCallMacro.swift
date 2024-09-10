//
//  RPCMacro.swift
//  MIOCoreMacros
//
//  Created by Javier Segura Perez on 9/9/24.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// Example from: https://github.com/swiftlang/swift-syntax/blob/main/Examples/Sources/MacroExamples/Implementation/Peer/AddAsyncMacro.swift

public struct ProcedureCallMacro: PeerMacro
{
    public static func expansion<Context: MacroExpansionContext,Declaration: DeclSyntaxProtocol>( of node: AttributeSyntax,
                                                                                                  providingPeersOf declaration: Declaration,
                                                                                                  in context: Context ) throws -> [DeclSyntax]
    {
        return []
    }
}

/*
@propertyWrapper
public struct ProcedureCall<T>
{
    public enum CallType {
        case local
        case remote
    }
    
    struct Config {
        enum ConfigType {
            case socket
            case url(method:String, endpoint:String)
        }
        
        var type:ConfigType
    }
    
    var _type:CallType
    var _config:Config
    
    var _value: T?
     
    public var wrappedValue: T {
        get { return _value! }
        set { _value = newValue }
    }
    
    init( type: CallType, config: Config ) {
        _type = type
        _config = config
    }
}
 */
