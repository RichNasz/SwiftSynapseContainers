// Generated from CodeGenSpecs/ContainerSpec.md — Do not edit manually. Update spec and re-generate.

import Foundation

#if Sandbox

// MARK: - ContainerizedResult

/// The result of an agent execution that ran inside a MicroVM.
///
/// Wraps the payload value alongside container resource metrics,
/// letting the host observe how much CPU and memory the isolated workload consumed.
public struct ContainerizedResult<T: Sendable>: Sendable {
    /// The return value from `execute(goal:)` as it ran inside the container.
    public let value: T
    /// The unique container instance ID (UUID string) assigned to this execution.
    public let containerID: String
    /// Total CPU time consumed by the guest in seconds.
    public let cpuTimeSeconds: Double
    /// Peak guest RAM usage in bytes.
    public let peakMemoryBytes: UInt64
    /// Wall-clock execution time in seconds (includes VM boot if not from a pool).
    public let wallTimeSeconds: Double

    public init(
        value: T,
        containerID: String,
        cpuTimeSeconds: Double,
        peakMemoryBytes: UInt64,
        wallTimeSeconds: Double
    ) {
        self.value = value
        self.containerID = containerID
        self.cpuTimeSeconds = cpuTimeSeconds
        self.peakMemoryBytes = peakMemoryBytes
        self.wallTimeSeconds = wallTimeSeconds
    }
}

// MARK: - ContainerizedAgentError

/// Errors that can be thrown from `containerized(goal:)` and `ContainerManager.run(goal:execute:)`.
public enum ContainerizedAgentError: Error, Sendable {
    /// The specified OCI image is not available locally. Pull it with `container pull <image>`.
    case imageNotFound(String)
    /// The virtual machine failed to reach the running state within the boot timeout.
    case bootFailed(String)
    /// Execution exceeded the timeout specified in `ContainerConfiguration.timeoutSeconds`.
    case timeoutExceeded(TimeInterval)
    /// Secure credential bundle injection into the guest environment failed.
    case injectionFailed(String)
    /// The guest VM exited with a non-zero exit code.
    case vmTerminated(Int32)
    /// The container CLI tool (`container`) is not installed or not in PATH.
    case containerToolNotFound
}

// MARK: - ContainerizedAgent

/// Protocol that `@Containerized` actors conform to.
///
/// This is the container counterpart to `AgentExecutable`. Every `@Containerized` actor
/// automatically conforms to both `AgentExecutable` (from `@SpecDrivenAgent`) and
/// `ContainerizedAgent` (from `@Containerized`).
///
/// Do not implement this protocol manually — use the `@Containerized` macro instead.
public protocol ContainerizedAgent: AgentExecutable {
    /// The MicroVM resource and security configuration.
    var containerConfig: ContainerConfiguration { get }
    /// The container instance ID from the most recent `containerized(goal:)` call. Nil when idle.
    var _containerID: String? { get set }
    /// Runs `execute(goal:)` inside a hardware-isolated MicroVM and returns the result with metrics.
    func containerized(goal: String) async throws -> ContainerizedResult<String>
}

#endif
