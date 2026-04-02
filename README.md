# SwiftSynapseContainers

Hardware-enforced MicroVM sandbox isolation for SwiftSynapse agents. Run each agent's
`execute(goal:)` payload inside an Apple Virtualization.framework virtual machine — true
per-agent security with no process-level cheats, no shared state, and no host exposure.

**macOS only.** `Virtualization.framework` does not exist on iOS or visionOS.

---

## Quick Start

### 1. Add the dependency

```swift
// Package.swift
.package(url: "https://github.com/RichNasz/SwiftSynapseContainers", branch: "main")
```

```swift
// Your target
.target(name: "MyAgent", dependencies: [
    .product(name: "SwiftSynapseContainers", package: "SwiftSynapseContainers"),
])
```

### 2. Annotate your agent

```swift
import SwiftSynapseContainers

@Containerized(image: "swift:latest", policy: .strict)
@SpecDrivenAgent
public actor CodeSandboxAgent {
    private let config: AgentConfiguration

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        _ = try configuration.buildLLMClient()
    }

    public func execute(goal: String) async throws -> String {
        let client = try config.buildLLMClient()
        let agent = Agent(client: client, model: config.modelName)
        return try await agent.respond(to: goal)
    }
}
```

### 3. Run in a container

```swift
let agent = try CodeSandboxAgent(configuration: config)

// Standard Harness run (hooks, permissions, resilience all apply in host):
let response = try await agent.run(goal: "Review this PR")

// Containerized run (execute() runs inside a MicroVM):
let result = try await agent.containerized(goal: "Compile and test this Swift snippet")
print("Peak memory: \(result.peakMemoryBytes / 1_048_576) MB")
print("CPU time: \(result.cpuTimeSeconds)s")
```

### 4. Install the container CLI (for OCI image management)

```bash
# Homebrew (when available)
brew install container

# Or download from https://github.com/apple/container/releases
container pull swift:latest
```

---

## Trait Selection

SwiftSynapseContainers uses SwiftPM Package Traits. Specify exactly what you need:

| Trait | What it enables | When to use |
|-------|----------------|-------------|
| `Sandbox` | `ContainerManager`, `MicroVMHandle`, `ContainerConfiguration`, `SandboxPolicy`, `ContainerizedAgent` | Isolation for a single agent |
| `ContainerPool` | Pre-warmed VM pool for near-instant allocation | Multi-agent crews, high-throughput pipelines |
| `SecureInjection` | Encrypted credential injection into guest VMs | API keys, tokens, secrets that must not appear in logs |
| `ContainerMonitoring` | Real-time CPU/memory metrics, health status callbacks | Production observability, kill switches |
| `ContainerPersistence` | Container snapshots and warm-restart state | Frequently-booted images, reduce cold-start latency |
| `SecureProduction` | Sandbox + ContainerPool + SecureInjection + ContainerMonitoring | **Default — recommended for most agents** |
| `Full` | SecureProduction + ContainerPersistence | Everything |

```swift
// Minimal (isolation only):
.package(url: "...", branch: "main", traits: ["Sandbox"])

// Default (zero config):
.package(url: "...", branch: "main")

// Everything:
.package(url: "...", branch: "main", traits: ["Full"])
```

---

## @Containerized Macro

```swift
@Containerized(
    image: "swift:latest",      // OCI image (must be pre-pulled)
    cpuCount: 2,                // vCPUs (default: 2)
    memoryGB: 4,                // guest RAM in GB (default: 4)
    diskGB: 20,                 // ephemeral disk in GB (default: 20)
    policy: .strict,            // security policy (default: .strict)
    timeoutSeconds: 300         // max wall time before VM is killed (default: 300)
)
```

The macro generates three members on the actor:
- `containerConfig: ContainerConfiguration` — the VM resource and security config
- `_containerID: String?` — the instance ID from the most recent `containerized()` call
- `containerized(goal:) async throws -> ContainerizedResult<String>` — the sandboxed execution entry point

And one extension:
- `MyAgent: ContainerizedAgent`

---

## ContainerConfiguration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `image` | `String` | (required) | OCI image name, e.g. `"swift:latest"` |
| `cpuCount` | `Int` | `2` | Number of guest vCPUs (minimum 1) |
| `memoryGB` | `UInt64` | `4` | Guest RAM in GB (minimum 1) |
| `diskGB` | `UInt64` | `20` | Ephemeral disk in GB (minimum 5) |
| `policy` | `SandboxPolicy` | `.strict` | Network and mount access policy |
| `networkEnabled` | `Bool` | `false` | Overridden to false when policy is `.strict` |
| `mounts` | `[VolumeMount]` | `[]` | Ignored unless policy is `.permissive` |
| `environment` | `[String: String]` | `[:]` | Environment variables injected at guest boot |
| `timeoutSeconds` | `TimeInterval` | `300` | Max wall-clock seconds before forceful kill |

Static factories: `.strict(image:)`, `.standard(image:)`, `.permissive(image:mounts:)`

---

## SandboxPolicy

| Policy | Network | Mounts | Use for |
|--------|---------|--------|---------|
| `.strict` | No | No | Untrusted code, third-party agents, supply-chain isolation |
| `.standard` | Outbound only | No | Trusted agents that need LLM API access |
| `.permissive` | Full outbound | Declared mounts | Trusted agents with explicit filesystem requirements |

---

## ContainerPool (parallel execution)

```swift
let pool = ContainerPool(size: 4, config: .strict(image: "swift:latest"))
await pool.prewarm()  // boot 4 VMs in parallel

// Concurrent sub-agent execution across isolated VMs:
async let r1 = pool.withContainer { m in try await m.run(goal: task1, execute: agent1.execute) }
async let r2 = pool.withContainer { m in try await m.run(goal: task2, execute: agent2.execute) }
async let r3 = pool.withContainer { m in try await m.run(goal: task3, execute: agent3.execute) }
let results = try await [r1, r2, r3]
```

---

## Secure Injection

Seal credentials before passing them to a container. The sealed bundle is decrypted
inside the guest VM; values never appear in goal strings, logs, or the `ObservableTranscript`.

```swift
let bundle = try SecureInjectionBundle(credentials: [
    "OPENAI_API_KEY": apiKey,
    "DATABASE_URL": dbURL,
])
// ContainerManager uses the bundle when injecting the goal into the VM
```

---

## Integration with SwiftSynapseHarness

`@Containerized` composes with `@SpecDrivenAgent`. All Harness features (hooks, permissions,
resilience, MCP, telemetry) run in the **host** and orchestrate the container. The container
runs only `execute(goal:)` — the pure domain logic.

```
Host: AgentHookPipeline, PermissionGate, RecoveryChain, AgentToolLoop
  └── ContainerManager
        └── MicroVM: execute(goal:) ← isolated here
```

`import SwiftSynapseContainers` re-exports `SwiftSynapseHarness` — one import gives you everything.

---

## Prerequisites

- Swift 6.2+
- macOS 26+
- `container` CLI tool installed (for OCI image pulls)
- Apple Silicon recommended (best Virtualization.framework performance)

---

## Related Packages

- [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness) — Production agent harness
- [SwiftSynapseMacros](https://github.com/RichNasz/SwiftSynapseMacros) — `@SpecDrivenAgent` and other macros
- [SwiftSynapse](https://github.com/RichNasz/SwiftSynapse) — Example agents

See [VISION.md](VISION.md) for the full design rationale.

---

## License

MIT. See [LICENSE](LICENSE).
