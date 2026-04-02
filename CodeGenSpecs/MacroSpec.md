# Spec: @Containerized Macro

**Generates:**
- `Sources/SwiftSynapseContainersMacros/Plugin.swift`
- `Sources/SwiftSynapseContainersMacros/ContainerizedMacro.swift`

---

## Overview

`@Containerized` is an attached macro that composes with `@SpecDrivenAgent`. It adds container lifecycle members to an actor and makes it conform to `ContainerizedAgent`.

**Attached to:** `actor` declarations (enforced at compile time with a diagnostic)
**Roles:** `@attached(member, ...)` + `@attached(extension, conformances: ContainerizedAgent)`

---

## Macro Declaration (in SwiftSynapseContainers library target)

```swift
/// Adds MicroVM container lifecycle to a @SpecDrivenAgent actor.
/// Generates containerConfig, _containerID, and containerized(goal:).
/// Attach to an `actor` declaration alongside @SpecDrivenAgent.
@attached(member, names: named(containerConfig), named(_containerID), named(containerized))
@attached(extension, conformances: ContainerizedAgent)
public macro Containerized(
    image: String,
    cpuCount: Int = 2,
    memoryGB: UInt64 = 4,
    diskGB: UInt64 = 20,
    policy: SandboxPolicy = .strict,
    timeoutSeconds: TimeInterval = 300
) = #externalMacro(module: "SwiftSynapseContainersMacros", type: "ContainerizedMacro")
```

**Placement in source:** Declared in `Sources/SwiftSynapseContainers/` (not in the macro plugin target). The macro plugin target is SwiftSyntax-only.

---

## Macro Plugin: Plugin.swift

```swift
// Generated from CodeGenSpecs/MacroSpec.md — Do not edit manually. Update spec and re-generate.
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftSynapseContainersMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ContainerizedMacro.self,
    ]
}
```

---

## Macro Implementation: ContainerizedMacro.swift

**Type:** `public struct ContainerizedMacro: MemberMacro, ExtensionMacro`

### ExtensionMacro expansion

- Guard: declaration must be `ActorDeclSyntax`, else return `[]`
- Returns: `extension <TypeName>: ContainerizedAgent {}`

### MemberMacro expansion

1. Guard that declaration is `ActorDeclSyntax`. If not, emit `ContainerizedDiagnostic.requiresActor` and return `[]`.
2. Determine `access` prefix from `actorDecl.modifiers` (same logic as `SpecDrivenAgentMacro`)
3. Extract macro arguments from `node.arguments`:
   - `image: String` (required)
   - `cpuCount: Int` (default 2)
   - `memoryGB: UInt64` (default 4)
   - `diskGB: UInt64` (default 20)
   - `policy: SandboxPolicy` (default `.strict`)
   - `timeoutSeconds: TimeInterval` (default 300)
4. Return these `DeclSyntax` members:
   ```swift
   public var containerConfig: ContainerConfiguration = ContainerConfiguration(
       image: "<image>",
       cpuCount: <cpuCount>,
       memoryGB: <memoryGB>,
       diskGB: <diskGB>,
       policy: .<policy>,
       networkEnabled: <networkEnabled>,
       mounts: [],
       environment: [:],
       timeoutSeconds: <timeoutSeconds>
   )
   public var _containerID: String? = nil
   public func containerized(goal: String) async throws -> ContainerizedResult<String> {
       let manager = ContainerManager(config: containerConfig)
       let result = try await manager.run(goal: goal) { [self] goal in
           try await self.execute(goal: goal)
       }
       _containerID = result.containerID
       return result
   }
   ```

**Note on argument extraction:** Parse `LabeledExprSyntax` from `node.arguments`. For each argument, match the label and extract the literal value. String literals: `.stringSegment`. Int/UInt64 literals: `.integerLiteral`. Double literals: `.floatLiteral` or `.integerLiteral`. Enum member access: `.memberAccess` → extract `.declName.baseName.text`.

---

## Diagnostic: ContainerizedDiagnostic

```swift
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
```

---

## Usage Example

```swift
@Containerized(image: "swift:latest", cpuCount: 2, memoryGB: 4, policy: .strict)
@SpecDrivenAgent
public actor CodeSandboxAgent {
    private let config: AgentConfiguration

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        _ = try configuration.buildLLMClient()
    }

    public func execute(goal: String) async throws -> String {
        // This body runs INSIDE the MicroVM when called via containerized(goal:)
        let client = try config.buildLLMClient()
        let agent = Agent(client: client, model: config.modelName)
        return try await agent.respond(to: goal)
    }
}

// Host call (agent.run calls agentRun which uses hooks/permissions/resilience):
let result = try await agent.run(goal: "Review this code for vulnerabilities")

// Direct containerized call (bypasses Harness run loop, uses container directly):
let containerResult = try await agent.containerized(goal: "Compile and run this Swift snippet")
print("Peak memory: \(containerResult.peakMemoryBytes / 1_048_576) MB")
```
