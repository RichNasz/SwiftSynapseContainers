// Generated from CodeGenSpecs/Traits.md — Do not edit manually. Update spec and re-generate.
//
// Provides no-op stubs for every cross-trait type reference.
// Core Sandbox files reference ContainerPool, SecureInjection, ContainerMonitoring, and
// ContainerPersistence types in method signatures. These stubs make those types available
// at compile time when the corresponding trait is disabled, so Sandbox-only builds compile.

// MARK: - ContainerPool Stubs

#if !ContainerPool

public actor ContainerPool {
    public init(size: Int, config: ContainerConfiguration) {}

    /// Always returns nil — real pooling requires the ContainerPool trait.
    public func allocate() async -> ContainerManager? { nil }

    public func release(_ manager: ContainerManager) async {}

    /// Always 0 — stub has no capacity.
    public var capacity: Int { 0 }
}

#endif

// MARK: - SecureInjection Stubs

#if !SecureInjection

public struct SecureInjectionBundle: Sendable {
    public init(credentials: [String: String] = [:]) {}
}

#endif

// MARK: - ContainerMonitoring Stubs

#if !ContainerMonitoring

public struct ContainerMetrics: Sendable {
    public var cpuTimeSeconds: Double = 0
    public var peakMemoryBytes: UInt64 = 0
    public var diskReadBytes: UInt64 = 0
    public var diskWriteBytes: UInt64 = 0
    public init() {}
}

#endif

// MARK: - ContainerPersistence Stubs

#if !ContainerPersistence

public struct ContainerSnapshot: Sendable {
    public var containerID: String = ""
    public var data: Data = Data()
    public var createdAt: Date = Date()
    public init() {}
}

#endif
