// Generated from CodeGenSpecs/ContainerSpec.md — Do not edit manually. Update spec and re-generate.

import Foundation

#if Sandbox

// MARK: - VolumeMount

/// A host-to-guest directory mapping. Only honoured when `SandboxPolicy.allowsMounts` is true.
public struct VolumeMount: Sendable {
    /// Absolute path on the host filesystem.
    public let hostPath: String
    /// Absolute path inside the guest VM.
    public let guestPath: String
    /// If true, the guest may only read from this mount.
    public let readOnly: Bool

    public init(hostPath: String, guestPath: String, readOnly: Bool = true) {
        self.hostPath = hostPath
        self.guestPath = guestPath
        self.readOnly = readOnly
    }
}

// MARK: - ContainerConfiguration

/// Immutable value type describing a MicroVM's resource limits, security policy, image, mounts,
/// environment variables, and execution timeout.
///
/// Pass to `ContainerManager` at init time or specify via `@Containerized` macro arguments.
///
/// ```swift
/// let config = ContainerConfiguration(
///     image: "swift:latest",
///     cpuCount: 2,
///     memoryGB: 4,
///     policy: .strict
/// )
/// ```
public struct ContainerConfiguration: Sendable {
    // MARK: - Properties

    /// OCI image name. Must be available locally (pre-pulled via `container pull <image>`).
    public let image: String

    /// Number of virtual CPUs allocated to the guest. Minimum 1, recommended 2.
    public let cpuCount: Int

    /// Guest RAM in gigabytes. Minimum 1, recommended 4.
    public let memoryGB: UInt64

    /// Ephemeral disk size in gigabytes. Minimum 5, recommended 20.
    public let diskGB: UInt64

    /// Security policy controlling network access and mount permissions.
    public let policy: SandboxPolicy

    /// Whether the guest has outbound network access. Always `false` when `policy == .strict`.
    public let networkEnabled: Bool

    /// Host-to-guest directory mounts. Always empty when `policy != .permissive`.
    public let mounts: [VolumeMount]

    /// Environment variables injected at guest boot time.
    public let environment: [String: String]

    /// Maximum wall-clock seconds before the VM is forcefully terminated.
    public let timeoutSeconds: TimeInterval

    // MARK: - Init

    public init(
        image: String,
        cpuCount: Int = 2,
        memoryGB: UInt64 = 4,
        diskGB: UInt64 = 20,
        policy: SandboxPolicy = .strict,
        networkEnabled: Bool = false,
        mounts: [VolumeMount] = [],
        environment: [String: String] = [:],
        timeoutSeconds: TimeInterval = 300
    ) {
        self.image = image
        self.cpuCount = max(1, cpuCount)
        self.memoryGB = max(1, memoryGB)
        self.diskGB = max(5, diskGB)
        self.policy = policy
        // Policy enforcement: strict always disables network regardless of parameter
        self.networkEnabled = (policy == .strict) ? false : networkEnabled
        // Policy enforcement: strict and standard disallow mounts regardless of parameter
        self.mounts = policy.allowsMounts ? mounts : []
        self.environment = environment
        self.timeoutSeconds = max(1, timeoutSeconds)
    }

    // MARK: - Static Factories

    /// A strict configuration with no network and no mounts. The most secure option.
    public static func strict(image: String) -> ContainerConfiguration {
        ContainerConfiguration(
            image: image,
            cpuCount: 2,
            memoryGB: 4,
            diskGB: 20,
            policy: .strict,
            networkEnabled: false,
            mounts: []
        )
    }

    /// A standard configuration with outbound network enabled and no mounts.
    /// Suitable for agents that need to call external APIs.
    public static func standard(image: String) -> ContainerConfiguration {
        ContainerConfiguration(
            image: image,
            cpuCount: 2,
            memoryGB: 4,
            diskGB: 20,
            policy: .standard,
            networkEnabled: true,
            mounts: []
        )
    }

    /// A permissive configuration with network and explicit mounts enabled.
    public static func permissive(image: String, mounts: [VolumeMount] = []) -> ContainerConfiguration {
        ContainerConfiguration(
            image: image,
            cpuCount: 4,
            memoryGB: 8,
            diskGB: 40,
            policy: .permissive,
            networkEnabled: true,
            mounts: mounts
        )
    }
}

#endif
