// Generated from CodeGenSpecs/MacroSpec.md — Do not edit manually. Update spec and re-generate.
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftSynapseContainersMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ContainerizedMacro.self,
    ]
}
