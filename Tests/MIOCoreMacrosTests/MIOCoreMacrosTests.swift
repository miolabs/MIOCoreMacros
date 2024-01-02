import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(MIOCoreMacrosPlugin)
import MIOCoreMacrosPlugin

let testMacros: [String: Macro.Type] = [    
    "ContextVar": ContextVarMacro.self,
    "OBJCProperty": OBJCPropertyMacro.self,
]
#endif

final class MIOCoreMacrosTests: XCTestCase {

    func testContextVarMacro() throws {
        #if canImport(MIOCoreMacros)
        assertMacroExpansion(
            """
            @ContextVar var user:User
            """,
            expandedSource: """
            var user:User {
                get {
                   var v = globals[ "_user_key_" ] as? User
                   if v == nil {
                       v = User()
                       globals[ "_user_key_" ] = v
                   }
                   return v!
                }
                set {
                   globals[ "_user_key_" ] = newValue
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testContextVarOptionalMacro() throws {
        #if canImport(MIOCoreMacros)
        assertMacroExpansion(
            """
            @ContextVar var user:User?
            """,
            expandedSource: """
            var user:User? {
                get {
                   return globals[ "_user_key_" ] as? User
                }
                set {
                   globals[ "_user_key_" ] = newValue
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testOBJCMacro() throws {
        #if canImport(MIOCoreMacros)
        assertMacroExpansion(
            """
            @OBJCProperty func hi() {}
            """,
            expandedSource: """
            func hi() {}
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    
}
