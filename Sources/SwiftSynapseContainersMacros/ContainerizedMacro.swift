// Generated from CodeGenSpecs/MacroSpec.md — Do not edit manually. Update spec and re-generate.
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ContainerizedMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(ActorDeclSyntax.self) else { return [] }
        let ext: DeclSyntax = "extension \(type.trimmed): ContainerizedAgent {}"
        return [ext.cast(ExtensionDeclSyntax.self)]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let actorDecl = declaration.as(ActorDeclSyntax.self) else {
            context.diagnose(.init(
                node: Syntax(node),
                message: ContainerizedDiagnostic.requiresActor
            ))
            return []
        }

        let isPublic = actorDecl.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
        let access = isPublic ? "public " : ""

        // Extract arguments from the macro attribute
        let args = extractArguments(from: node)

        guard let image = args["image"] else {
            context.diagnose(.init(
                node: Syntax(node),
                message: ContainerizedDiagnostic.missingImageArgument
            ))
            return []
        }

        let cpuCount  = args["cpuCount"]       ?? "2"
        let memoryGB  = args["memoryGB"]        ?? "4"
        let diskGB    = args["diskGB"]          ?? "20"
        let policy    = args["policy"]          ?? ".strict"
        let timeout   = args["timeoutSeconds"]  ?? "300"

        // Derive networkEnabled from policy string
        let networkEnabled = (policy == ".standard" || policy == ".permissive") ? "true" : "false"

        return [
            """
            \(raw: access)var containerConfig: ContainerConfiguration = ContainerConfiguration(
                image: \(raw: image),
                cpuCount: \(raw: cpuCount),
                memoryGB: \(raw: memoryGB),
                diskGB: \(raw: diskGB),
                policy: \(raw: policy),
                networkEnabled: \(raw: networkEnabled),
                mounts: [],
                environment: [:],
                timeoutSeconds: \(raw: timeout)
            )
            """,
            "\(raw: access)var _containerID: String? = nil",
            """
            \(raw: access)func containerized(goal: String) async throws -> ContainerizedResult<String> {
                let manager = ContainerManager(config: containerConfig)
                let result = try await manager.run(goal: goal) { [self] goal in
                    try await self.execute(goal: goal)
                }
                _containerID = result.containerID
                return result
            }
            """,
        ]
    }

    // MARK: - Argument Extraction

    private static func extractArguments(from node: AttributeSyntax) -> [String: String] {
        var result: [String: String] = [:]
        guard let args = node.arguments?.as(LabeledExprListSyntax.self) else {
            return result
        }
        for arg in args {
            guard let label = arg.label?.text else { continue }
            let expr = arg.expression.trimmedDescription
            result[label] = expr
        }
        return result
    }
}

// MARK: - Diagnostics

enum ContainerizedDiagnostic: String, DiagnosticMessage {
    case requiresActor
    case missingImageArgument

    var message: String {
        switch self {
        case .requiresActor:
            return "@Containerized can only be applied to an actor"
        case .missingImageArgument:
            return "@Containerized requires an `image:` argument (e.g., @Containerized(image: \"swift:latest\"))"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "SwiftSynapseContainersMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
