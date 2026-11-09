import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(MIOCoreMacrosPlugin)
import MIOCoreMacrosPlugin
import MIOExportCore

let exportMacros: [String: Macro.Type] = [ "Export": ExportMacro.self ]

final class ExportMacroTests: XCTestCase {

    func testNumbersAndOptionalString () {
        assertMacroExpansion(
            """
            @Export( "dlr_sort" )
            func sort ( table: Int, key: String?, ascending: Bool = true ) -> Int { 0 }
            """,
            expandedSource: """
            func sort ( table: Int, key: String?, ascending: Bool = true ) -> Int { 0 }

            #if os(WASI)
            @_expose(wasm, "dlr_sort")
            @_cdecl("dlr_sort")
            public func _mio_export_sort ( _ a0: Int32, _ a1: UnsafeRawPointer?, _ a1Length: Int32, _ a2: Int32 ) -> Int32 {
                let r = sort( table: Int( a0 ), key: MCWasm.optionalString( a1, a1Length ), ascending: a2 != 0 )
                return Int32( truncatingIfNeeded: r )
            }
            #endif
            """,
            macros: exportMacros
        )
    }

    func testThrowingStringResultAndDefaultSymbol () {
        assertMacroExpansion(
            """
            @Export
            func rowsHTML ( _ table: Int, from: Int, to: Int ) throws -> String { "" }
            """,
            expandedSource: """
            func rowsHTML ( _ table: Int, from: Int, to: Int ) throws -> String { "" }

            #if os(WASI)
            @_expose(wasm, "rowsHTML")
            @_cdecl("rowsHTML")
            public func _mio_export_rowsHTML ( _ a0: Int32, _ a1: Int32, _ a2: Int32 ) -> UnsafeMutableRawPointer? {
                do {
                    let r = try rowsHTML( Int( a0 ), from: Int( a1 ), to: Int( a2 ) )
                    return MCWasm.buffer( r )
                } catch {
                    MCWasm.fail( error )
                    return nil
                }
            }
            #endif
            """,
            macros: exportMacros
        )
    }

    func testCodableDataAndVoid () {
        assertMacroExpansion(
            """
            @Export( "lib_store" )
            func store ( options: Options?, payload: Data ) -> Info { Info() }
            @Export( "lib_reset" )
            func reset ( ) { }
            """,
            expandedSource: """
            func store ( options: Options?, payload: Data ) -> Info { Info() }

            #if os(WASI)
            @_expose(wasm, "lib_store")
            @_cdecl("lib_store")
            public func _mio_export_store ( _ a0: UnsafeRawPointer?, _ a0Length: Int32, _ a1: UnsafeRawPointer?, _ a1Length: Int32 ) -> UnsafeMutableRawPointer? {
                do {
                    let r = try store( options: ( a0Length < 0 ? nil : MCWasm.json( Options.self, a0, a0Length ) ), payload: MCWasm.data( a1, a1Length ) )
                    return MCWasm.buffer( json: r )
                } catch {
                    MCWasm.fail( error )
                    return nil
                }
            }
            #endif
            func reset ( ) { }

            #if os(WASI)
            @_expose(wasm, "lib_reset")
            @_cdecl("lib_reset")
            public func _mio_export_reset ( ) {
                reset( )
            }
            #endif
            """,
            macros: exportMacros
        )
    }

    func testUnsupportedDeclarationsAreDiagnosed () {
        assertMacroExpansion(
            """
            @Export
            func count ( limit: Int? ) -> Int { 0 }
            """,
            expandedSource: """
            func count ( limit: Int? ) -> Int { 0 }
            """,
            diagnostics: [ DiagnosticSpec( message: "@Export cannot pass an optional Int; use a non-optional value or a Codable type", line: 1, column: 1 ) ],
            macros: exportMacros
        )
        assertMacroExpansion(
            """
            @Export
            func load ( ) async -> Int { 0 }
            """,
            expandedSource: """
            func load ( ) async -> Int { 0 }
            """,
            diagnostics: [ DiagnosticSpec( message: "@Export functions cannot be async", line: 1, column: 1 ) ],
            macros: exportMacros
        )
    }
}

final class ExportBindingsTests: XCTestCase {

    let source = """
    /// Loads a report.
    @Export( "dlr_load" )
    func load ( json: Data, locale: String = "es_ES" ) throws { }

    #if os(WASI)
    @Export( "dlr_sort" )
    func sort ( table: Int, key: String? = nil, ascending: Bool = true ) -> Int { 0 }
    #endif

    @Export( "dlr_info" ) func info ( _ table: Int, default: Bool ) -> Info? { nil }
    @Export( "dlr_html" ) func html ( _ table: Int ) -> String? { nil }
    func notExported ( ) { }
    """

    func testScannerFindsExportsInsideIfConfig () throws {
        let functions = try ExportScanner.scan( source: source )
        XCTAssertEqual( functions.map { $0.symbol }, [ "dlr_load", "dlr_sort", "dlr_info", "dlr_html" ] )
        XCTAssertEqual( functions[ 0 ].documentation, [ "Loads a report." ] )
        XCTAssertEqual( functions[ 1 ].parameters.map { $0.defaultLiteral }, [ nil, "null", "true" ] )
        XCTAssertTrue( functions[ 0 ].canFail )
        XCTAssertFalse( functions[ 1 ].canFail )
    }

    func testJavaScript () throws {
        let js = JSBindings( className: "Kit", functions: try ExportScanner.scan( source: source ) ).javaScript
        XCTAssertTrue( js.contains( "import { MIOWasm } from \"./miowasm.js\";" ) )
        XCTAssertTrue( js.contains( """
            /** Loads a report. */
            load( json, locale = "es_ES" ) {
                this.wasm.call( "dlr_load", json, locale );
                this._check();
            }
        """ ), js )
        XCTAssertTrue( js.contains( """
            sort( table, key = null, ascending = true ) {
                const r = this.wasm.call( "dlr_sort", table | 0, key, !!ascending );
                return r;
            }
        """ ), js )
        // reserved words are renamed; optional Encodable is JSON
        XCTAssertTrue( js.contains( "info( table, default_ ) {" ), js )
        XCTAssertTrue( js.contains( "return this.wasm.readJSON( r );" ), js )
        XCTAssertTrue( js.contains( "return r === 0 ? null : this.wasm.readString( r );" ), js )
    }

    func testTypeScript () throws {
        let ts = JSBindings( className: "Kit", functions: try ExportScanner.scan( source: source ) ).typeScript
        XCTAssertTrue( ts.contains( "load( json: Uint8Array | string, locale?: string ): void;" ), ts )
        XCTAssertTrue( ts.contains( "sort( table: number, key?: string | null, ascending?: boolean ): number;" ), ts )
        XCTAssertTrue( ts.contains( "html( table: number ): string | null;" ), ts )
    }

    func testScannerReportsUnsupportedFunctions () {
        XCTAssertThrowsError( try ExportScanner.scan( source: "@Export func f ( x: Double? ) { }", file: "A.swift" ) ) {
            XCTAssertEqual( "\( $0 )", "A.swift: f: @Export cannot pass an optional Double; use a non-optional value or a Codable type" )
        }
    }
}
#endif
