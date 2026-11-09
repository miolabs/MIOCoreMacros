//
//  WasmWrapper.swift
//  MIOExportCore
//
//  The Swift source of the `@_expose(wasm)` / `@_cdecl` wrapper @Export puts next to a
//  function. It is inside `#if os(WASI)`: MCWasm (MIOCoreWasm) only exists there, and the
//  function itself stays plain Swift that builds and tests on every platform.
//

extension ExportedFunction {

    public var wasmWrapperSource: String {
        var arguments: [String] = []      // the wrapper's C parameters
        var call: [String] = []           // the arguments of the call to the function
        for ( i, p ) in parameters.enumerated( ) {
            let a = "a\( i )"
            let label = p.label.map { $0 + ": " } ?? ""
            switch p.type.kind {
            case .int:
                arguments.append( "_ \( a ): Int32" ); call.append( label + "Int( \( a ) )" )
            case .int32:
                arguments.append( "_ \( a ): Int32" ); call.append( label + a )
            case .double:
                arguments.append( "_ \( a ): Double" ); call.append( label + a )
            case .float:
                arguments.append( "_ \( a ): Float" ); call.append( label + a )
            case .bool:
                arguments.append( "_ \( a ): Int32" ); call.append( label + "\( a ) != 0" )
            case .string, .data, .bytes, .json:
                arguments.append( "_ \( a ): UnsafeRawPointer?" )
                arguments.append( "_ \( a )Length: Int32" )
                call.append( label + bufferArgument( p.type, a ) )
            }
        }

        let ( resultType, convert, failure ) = resultConversion
        let invocation = "\( canFail ? "try " : "" )\( swiftName )\( ExportedFunction.parenthesized( call ) )"
        var body: String
        if result == nil {
            body = canFail ? "        \( invocation )\n" : "    \( invocation )\n"
        } else {
            body = ( canFail ? "        " : "    " ) + "let r = \( invocation )\n"
                 + ( canFail ? "        " : "    " ) + "return \( convert )\n"
        }
        if canFail {
            body = "    do {\n" + body
                 + "    } catch {\n"
                 + "        MCWasm.fail( error )\n"
                 + ( failure.map { "        return \( $0 )\n" } ?? "" )
                 + "    }\n"
        }

        let signature = ExportedFunction.parenthesized( arguments )
        return """
        #if os(WASI)
        @_expose(wasm, "\( symbol )")
        @_cdecl("\( symbol )")
        public func \( wrapperName ) \( signature )\( resultType.map { " -> " + $0 } ?? "" ) {
        \( body )}
        #endif
        """
    }

    static func parenthesized ( _ items: [String] ) -> String {
        items.isEmpty ? "( )" : "( " + items.joined( separator: ", " ) + " )"
    }

    func bufferArgument ( _ type: ExportType, _ a: String ) -> String {
        let length = a + "Length"
        let value: String
        switch type.kind {
        case .string: return type.optional ? "MCWasm.optionalString( \( a ), \( length ) )" : "MCWasm.string( \( a ), \( length ) )"
        case .data: value = "MCWasm.data( \( a ), \( length ) )"
        case .bytes: value = "Array( MCWasm.data( \( a ), \( length ) ) )"
        case .json( let t ): value = "MCWasm.json( \( t ).self, \( a ), \( length ) )"
        default: value = a
        }
        // JS passes null as (0, -1)
        return type.optional ? "( \( length ) < 0 ? nil : \( value ) )" : value
    }

    /// (C result type, expression converting `r`, value returned after an error).
    var resultConversion: ( String?, String, String? ) {
        guard let result = result else { return ( nil, "", nil ) }
        switch result.kind {
        case .int: return ( "Int32", "Int32( truncatingIfNeeded: r )", "0" )
        case .int32: return ( "Int32", "r", "0" )
        case .double: return ( "Double", "r", "0" )
        case .float: return ( "Float", "r", "0" )
        case .bool: return ( "Int32", "r ? 1 : 0", "0" )
        case .json:
            // An optional Encodable encodes as JSON null, so the buffer is always there
            return ( canFail ? "UnsafeMutableRawPointer?" : "UnsafeMutableRawPointer", "MCWasm.buffer( json: r )", "nil" )
        case .string, .data, .bytes:
            let buffer = result.kind == .bytes ? "MCWasm.buffer( Data( $0 ) )" : "MCWasm.buffer( $0 )"
            if result.optional {
                return ( "UnsafeMutableRawPointer?", "r.map { \( buffer ) }", "nil" )
            }
            let direct = result.kind == .bytes ? "MCWasm.buffer( Data( r ) )" : "MCWasm.buffer( r )"
            return ( canFail ? "UnsafeMutableRawPointer?" : "UnsafeMutableRawPointer", direct, "nil" )
        }
    }
}
