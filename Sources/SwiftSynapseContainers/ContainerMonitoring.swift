// Generated from CodeGenSpecs/ContainerSpec.md — Do not edit manually. Update spec and re-generate.

import Foundation

#if ContainerMonitoring

// MARK: - ContainerMetrics

/// Real-time and aggregate resource metrics for a running MicroVM.
public struct ContainerMetrics: Sendable {
    /// Total CPU time consumed by the guest in seconds.
    public var cpuTimeSeconds: Double
    /// Peak guest RAM usage in bytes.
    public var peakMemoryBytes: UInt64
    /// Total bytes read from the ephemeral disk.
    public var diskReadBytes: UInt64
    /// Total bytes written to the ephemeral disk.
    public var diskWriteBytes: UInt64
    /// Network bytes received (always 0 for `.strict` policy).
    public var networkReceivedBytes: UInt64
    /// Network bytes sent (always 0 for `.strict` policy).
    public var networkSentBytes: UInt64

    public init(
        cpuTimeSeconds: Double = 0,
        peakMemoryBytes: UInt64 = 0,
        diskReadBytes: UInt64 = 0,
        diskWriteBytes: UInt64 = 0,
        networkReceivedBytes: UInt64 = 0,
        networkSentBytes: UInt64 = 0
    ) {
        self.cpuTimeSeconds = cpuTimeSeconds
        self.peakMemoryBytes = peakMemoryBytes
        self.diskReadBytes = diskReadBytes
        self.diskWriteBytes = diskWriteBytes
        self.networkReceivedBytes = networkReceivedBytes
        self.networkSentBytes = networkSentBytes
    }
}

// MARK: - ContainerHealthStatus

/// The observed health state of a running container.
public enum ContainerHealthStatus: Sendable {
    case healthy
    case degraded(String)   // running but resource-constrained; description of pressure
    case critical(String)   // about to be killed; description of violation
    case terminated(Int32)  // VM has stopped; exit code
}

// MARK: - ContainerHealthMonitor

/// Actor that continuously samples resource metrics from a running `MicroVMHandle`
/// and fires callbacks when thresholds are exceeded.
public actor ContainerHealthMonitor {
    // MARK: - Configuration

    public struct Thresholds: Sendable {
        /// Memory usage fraction (0.0–1.0) above which status becomes `.degraded`.
        public var degradedMemoryFraction: Double = 0.8
        /// Memory usage fraction (0.0–1.0) above which status becomes `.critical`.
        public var criticalMemoryFraction: Double = 0.95
        /// CPU time per wall-second above which status becomes `.degraded`.
        public var degradedCPUFraction: Double = 0.9
        public init() {}
    }

    // MARK: - State

    private let thresholds: Thresholds
    private let pollingInterval: TimeInterval
    private var latestMetrics: ContainerMetrics = ContainerMetrics()
    private var status: ContainerHealthStatus = .healthy
    private var onStatusChange: (@Sendable (ContainerHealthStatus) -> Void)?

    // MARK: - Init

    public init(
        thresholds: Thresholds = Thresholds(),
        pollingInterval: TimeInterval = 1.0
    ) {
        self.thresholds = thresholds
        self.pollingInterval = pollingInterval
    }

    // MARK: - Monitoring

    /// Registers a callback fired whenever health status changes.
    public func onStatusChange(_ handler: @Sendable @escaping (ContainerHealthStatus) -> Void) {
        self.onStatusChange = handler
    }

    /// Returns the most recently sampled metrics.
    public var metrics: ContainerMetrics { latestMetrics }

    /// Returns the current health status.
    public var currentStatus: ContainerHealthStatus { status }

    /// Starts polling `handle` at `pollingInterval` until `stop()` is called.
    public func start(monitoring handle: MicroVMHandle, config: ContainerConfiguration) async {
        while true {
            let state = await handle.state
            guard case .running = state else { break }

            // Production implementation queries VZVirtualMachine resource usage APIs.
            // Bootstrap: no-op (metrics remain at default zero values).
            latestMetrics = ContainerMetrics()

            let memoryLimit = config.memoryGB * 1024 * 1024 * 1024
            let memoryFraction = memoryLimit > 0
                ? Double(latestMetrics.peakMemoryBytes) / Double(memoryLimit)
                : 0.0

            let newStatus: ContainerHealthStatus
            if memoryFraction >= thresholds.criticalMemoryFraction {
                newStatus = .critical("Memory usage at \(Int(memoryFraction * 100))%")
            } else if memoryFraction >= thresholds.degradedMemoryFraction {
                newStatus = .degraded("Memory usage at \(Int(memoryFraction * 100))%")
            } else {
                newStatus = .healthy
            }

            if case .healthy = status, case .healthy = newStatus {} else {
                status = newStatus
                onStatusChange?(newStatus)
            }

            try? await Task.sleep(for: .seconds(pollingInterval))
        }
        status = .terminated(0)
        onStatusChange?(.terminated(0))
    }
}

#endif
