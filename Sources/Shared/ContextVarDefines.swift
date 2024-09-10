//
//  ContextVarDefines.swift
//  MIOCoreMacros
//
//  Created by Javier Segura Perez on 10/9/24.
//

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
