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

/// Exports a global function to WebAssembly (and, through mio-wasm-bindings, to JavaScript).
/// The function stays plain Swift; the generated wrapper exists only when building for WASI
/// and uses MIOCoreWasm, so the file needs `#if os(WASI) import MIOCoreWasm #endif`.
///
///     @Export( "dlr_sort" )
///     func sort ( table: Int, key: String?, ascending: Bool = true ) throws -> Int
///
/// `symbol` is the wasm export name (default: the function name). Arguments and results:
/// Int, Int32, Double, Float, Bool, String(?), Data(?), [UInt8](?) and any Codable type
/// (passed as JSON). Throwing functions report the error to JS, which rethrows it.
@attached(peer, names: prefixed(_mio_export_))
public macro Export( _ symbol: String? = nil ) = #externalMacro( module: "MIOCoreMacrosPlugin", type: "ExportMacro" )
