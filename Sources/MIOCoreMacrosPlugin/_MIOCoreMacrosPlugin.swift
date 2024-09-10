import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MIOCoreMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ContextVarMacro.self,
        OBJCPropertyMacro.self,
        ProcedureCallMacro.self
    ]
}
