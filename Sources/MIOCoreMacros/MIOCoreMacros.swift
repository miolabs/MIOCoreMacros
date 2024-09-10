// The Swift Programming Language
// https://docs.swift.org/swift-book

import Shared

/// A macro that produces both a value and a string containing the
/// source code that generated the value. For example,
///
///     #stringify(x + y)
///
/// produces a tuple `(x + y, "x + y")`.
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MIOCoreMacrosPlugin", type: "StringifyMacro")

public typealias ContextVarInitBlock = () -> Any

@attached(accessor)
public macro ContextVar( accessor: ContextVarAccessor = .readAndWrite, initBlock:ContextVarInitBlock? = nil) = #externalMacro( module: "MIOCoreMacrosPlugin", type: "ContextVarMacro" )

@attached(peer, names: overloaded)
public macro ProcedureCall() = #externalMacro(module: "MIOCoreMacrosPlugin", type: "ProcedureCallMacro")
