// Generated from CodeGenSpecs/ContainerSpec.md — Do not edit manually. Update spec and re-generate.

#if Sandbox

// MARK: - SandboxPolicy

/// Controls the security posture of a MicroVM.
///
/// Choose based on how much trust you extend to the workload running inside the container:
/// - `.strict` — untrusted code, third-party agents, supply-chain isolation
/// - `.standard` — trusted agents that need LLM API access (outbound only)
/// - `.permissive` — trusted agents with declared read-write mount requirements
public enum SandboxPolicy: String, Sendable, CaseIterable {
    /// No network, no host mounts, minimal resource footprint.
    /// The most secure option. Suitable for untrusted code execution and supply-chain isolation.
    case strict

    /// Controlled outbound network (no inbound), read-only OS mounts.
    /// Suitable for trusted agents that need to call external APIs (e.g., LLM providers).
    case standard

    /// Full outbound network, controlled read-write mounts declared in `ContainerConfiguration.mounts`.
    /// Suitable for trusted agents with explicit filesystem requirements.
    case permissive

    // MARK: - Derived Properties

    /// Whether guest outbound network access is enabled for this policy.
    public var networkEnabled: Bool {
        switch self {
        case .strict:      return false
        case .standard:    return true
        case .permissive:  return true
        }
    }

    /// Whether host-to-guest directory mounts are permitted for this policy.
    public var allowsMounts: Bool {
        switch self {
        case .strict:      return false
        case .standard:    return false
        case .permissive:  return true
        }
    }

    /// Human-readable description for logs and diagnostics.
    public var description: String {
        switch self {
        case .strict:
            return "strict (no network, no mounts)"
        case .standard:
            return "standard (outbound network, read-only mounts)"
        case .permissive:
            return "permissive (full network, declared read-write mounts)"
        }
    }
}

#endif
