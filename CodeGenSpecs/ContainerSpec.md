# Spec: Sandbox Trait

**Generates:**
- `Sources/SwiftSynapseContainers/ContainerConfiguration.swift`
- `Sources/SwiftSynapseContainers/SandboxPolicy.swift`
- `Sources/SwiftSynapseContainers/ContainerizedAgent.swift`
- `Sources/SwiftSynapseContainers/MicroVMHandle.swift`
- `Sources/SwiftSynapseContainers/ContainerManager.swift`

All files are guarded with `#if Sandbox` / `#endif`.

---

## ContainerConfiguration

**Purpose:** Immutable value type describing a MicroVM's resource limits, security policy, image, mounts, environment, and timeout. Passed to `ContainerManager` at init time.

**Type:** `public struct ContainerConfiguration: Sendable`

**Properties:**
- `image: String` — OCI image name (e.g., `"swift:latest"`, `"ubuntu:24.04"`)
- `cpuCount: Int` — vCPU count (default: 2, minimum: 1)
- `memoryGB: UInt64` — guest RAM in GB (default: 4, minimum: 1)
- `diskGB: UInt64` — ephemeral disk size in GB (default: 20, minimum: 5)
- `policy: SandboxPolicy` — security policy (default: `.strict`)
- `networkEnabled: Bool` — guest network access (overridden to false when policy is `.strict`)
- `mounts: [VolumeMount]` — host→guest directory mounts (empty for `.strict` policy)
- `environment: [String: String]` — environment variables injected at boot (default: empty)
- `timeoutSeconds: TimeInterval` — max execution time before forceful VM termination (default: 300)

**Nested type:** `VolumeMount: Sendable`
- `hostPath: String`
- `guestPath: String`
- `readOnly: Bool`

**Static factories:**
- `ContainerConfiguration.strict(image:)` — policy: .strict, no network, no mounts, 2 vCPU, 4 GB RAM, 20 GB disk
- `ContainerConfiguration.standard(image:)` — policy: .standard, network enabled, read-only OS mounts
- `ContainerConfiguration.permissive(image:)` — policy: .permissive, network + mounts enabled

**Init:** `public init(image:cpuCount:memoryGB:diskGB:policy:networkEnabled:mounts:environment:timeoutSeconds:)` with all defaults.

**Rule:** If `policy == .strict`, `networkEnabled` is always `false` regardless of the parameter passed. Mounts are always empty for `.strict`.

---

## SandboxPolicy

**Purpose:** Enum controlling the security posture of the MicroVM.

**Type:** `public enum SandboxPolicy: String, Sendable, CaseIterable`

**Cases:**
- `.strict` — no network, no host mounts, minimal resource footprint. For untrusted code, third-party agents, supply-chain isolation.
- `.standard` — controlled outbound network (no inbound), read-only OS mounts only. For trusted agents that need LLM API access.
- `.permissive` — full outbound network, controlled read-write mounts. For trusted agents with explicit mount declarations.

**Properties:**
- `var networkEnabled: Bool` — true for standard and permissive
- `var allowsMounts: Bool` — true for permissive only
- `var description: String` — human-readable description for logs

---

## ContainerizedAgent

**Purpose:** Protocol that `@Containerized` actors conform to. The container counterpart to `AgentExecutable`.

**Type:** `public protocol ContainerizedAgent: AgentExecutable`

**Requirements:**
- `var containerConfig: ContainerConfiguration { get }` — the container configuration
- `var _containerID: String? { get set }` — the active container ID (nil when idle)
- `func containerized(goal: String) async throws -> ContainerizedResult<String>` — runs `execute(goal:)` inside a MicroVM

**Associated nested type:** `ContainerizedResult<T: Sendable>: Sendable`
- `value: T` — the payload result
- `containerID: String` — the container instance ID used
- `cpuTimeSeconds: Double` — total CPU time consumed
- `peakMemoryBytes: UInt64` — peak guest RAM usage
- `wallTimeSeconds: Double` — wall-clock execution time

**Error:** `ContainerizedAgentError: Error, Sendable`
- `case imageNotFound(String)` — OCI image not available locally
- `case bootFailed(String)` — VM failed to reach running state
- `case timeoutExceeded(TimeInterval)` — execution exceeded `containerConfig.timeoutSeconds`
- `case injectionFailed(String)` — secure bundle injection failed
- `case vmTerminated(Int32)` — VM exited with non-zero exit code

---

## MicroVMHandle

**Purpose:** Lightweight handle to a running `VZVirtualMachine`. Tracks lifecycle state and exposes safe async start/stop APIs.

**Type:** `public actor MicroVMHandle`

**Properties:**
- `private var vm: VZVirtualMachine`
- `private(set) var containerID: String` — UUID string assigned at creation
- `private(set) var state: MicroVMState`

**Enum:** `public enum MicroVMState: Sendable` — `.starting`, `.running`, `.stopping`, `.stopped`, `.failed(String)`

**Methods:**
- `func start() async throws` — boot the VM; throws if already running
- `func stop() async throws` — graceful shutdown; waits up to 5s before force-stop
- `func forceStop()` — immediate termination (used on timeout)
- `func waitForRunning(timeout: TimeInterval) async throws` — polls state until `.running` or throws `ContainerizedAgentError.bootFailed`

**Init:** `public init(configuration: VZVirtualMachineConfiguration) throws` — validates and creates the `VZVirtualMachine`

**Rule:** MicroVMHandle owns the VZVirtualMachine lifecycle. ContainerManager owns MicroVMHandles.

---

## ContainerManager

**Purpose:** Actor that manages the full lifecycle of a single MicroVM execution for one agent invocation. Created per `containerized(goal:)` call (or allocated from ContainerPool if available).

**Type:** `public actor ContainerManager`

**Properties:**
- `private let config: ContainerConfiguration`
- `private var handle: MicroVMHandle?`

**Key method:**
```swift
public func run(
    goal: String,
    execute: @Sendable (String) async throws -> String
) async throws -> ContainerizedResult<String>
```

**Execution steps:**
1. Pull/verify the OCI image is present locally (via `container` CLI subprocess — `container pull <image>` if not cached)
2. Build a `VZVirtualMachineConfiguration` from `ContainerConfiguration`
   - Linux boot loader (`VZLinuxBootLoader`) with kernel + initrd embedded from image
   - vCPUs, memory, disk from config
   - Network device if `config.networkEnabled`
   - VirtioFS shares for mounts if `config.allowsMounts`
3. Create `MicroVMHandle` and boot the VM
4. Inject the goal string and environment via the VM's virtio-serial port
5. Await the result via the same serial port (JSON-encoded)
6. Collect metrics (CPU time, peak memory) from `VZVirtualMachine`
7. Stop the VM and return `ContainerizedResult`
8. On timeout: call `handle.forceStop()`, throw `.timeoutExceeded`

**Private helpers:**
- `private func verifyImage(_ image: String) async throws` — runs `container image inspect <image>` as subprocess; throws `.imageNotFound` if not present
- `private func buildVMConfig() throws -> VZVirtualMachineConfiguration`
- `private func injectAndAwait(goal: String, via handle: MicroVMHandle) async throws -> (String, ContainerMetrics)`
- `private func containerImage(for image: String) -> URL` — resolves image rootfs path

**Rule:** ContainerManager never caches VMs. ContainerPool is responsible for pooling. ContainerManager is always created fresh unless allocated from a pool.
