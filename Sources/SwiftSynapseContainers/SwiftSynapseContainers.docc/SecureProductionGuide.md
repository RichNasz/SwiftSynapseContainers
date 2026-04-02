# Secure Production Guide

Deploy containerized agents with credential injection, real-time monitoring, and container state persistence.

## Overview

The `SecureProduction` trait bundle — the default — combines four subsystems:

- **Sandbox** — MicroVM isolation via `Virtualization.framework`
- **ContainerPool** — Pre-warmed VM pool for near-instant allocation
- **SecureInjection** — Encrypted credential delivery into guest VMs
- **ContainerMonitoring** — Real-time CPU/memory metrics with health callbacks

Add `ContainerPersistence` via `traits: ["Full"]` for container snapshot support.

## Secure Injection

Never pass credentials in the goal string — they appear in `ObservableTranscript` and logs. Use ``SecureInjectionBundle`` to seal secrets before they enter the guest:

```swift
let bundle = try SecureInjectionBundle(credentials: [
    "OPENAI_API_KEY": apiKey,
    "DATABASE_URL":   databaseURL,
    "S3_BUCKET":      bucketName,
])
```

``SecureInjectionBundle`` uses Curve25519 key agreement and AES-GCM encryption. The sealed bundle is transmitted to the guest via virtio-serial and decrypted by the guest's init process. The plaintext credentials are only available inside the VM.

## Container Monitoring

``ContainerHealthMonitor`` polls a running VM and fires status change callbacks when resource thresholds are exceeded:

```swift
let monitor = ContainerHealthMonitor(
    thresholds: .init(
        degradedMemoryFraction: 0.75,
        criticalMemoryFraction:  0.90,
        degradedCPUFraction:     0.85
    ),
    pollingInterval: 0.5
)

await monitor.onStatusChange { status in
    switch status {
    case .degraded(let reason):
        logger.warning("Container degraded: \(reason)")
    case .critical(let reason):
        logger.error("Container critical: \(reason) — will be killed")
    case .terminated(let code):
        logger.info("Container exited: \(code)")
    default:
        break
    }
}
```

``ContainerMetrics`` exposes CPU time, peak memory, and disk I/O:

```swift
let metrics = await monitor.metrics
print("CPU:    \(metrics.cpuTimeSeconds)s")
print("Memory: \(metrics.peakMemoryBytes / 1_048_576) MB")
print("Disk R: \(metrics.diskReadBytes / 1024) KB")
print("Disk W: \(metrics.diskWriteBytes / 1024) KB")
```

## Container Persistence

Enable the `ContainerPersistence` trait to snapshot VM state for warm restarts. Snapshots skip the full boot sequence — useful for frequently-used images with slow init:

```swift
let store = ContainerSnapshotStore()

// Save a snapshot after a successful run
let snapshot = ContainerSnapshot(
    containerID: result.containerID,
    image: "swift:latest",
    data: vmStateData  // captured from VZVirtualMachine
)
try await store.save(snapshot)

// Load on next run
if let snapshot = try await store.load(for: "swift:latest") {
    // Restore VM from snapshot instead of cold boot
}
```

Snapshots are stored at `~/Library/Caches/com.swiftsynapse.containers/snapshots/` by default. Provide a custom `baseDirectory` for multi-user or shared deployments.

## Production Checklist

Before shipping containerized agents to production:

- **Images pre-pulled** — run `container pull <image>` in your deployment pipeline; `ContainerManager` will throw ``ContainerizedAgentError/imageNotFound(_:)`` at runtime if the image is missing
- **Virtualization entitlement** — add `com.apple.security.virtualization` to your `.entitlements` file for distribution builds
- **Resource sizing** — run a load test and inspect `ContainerizedResult.peakMemoryBytes` to right-size `memoryGB` in ``ContainerConfiguration``
- **Timeout tuning** — set `timeoutSeconds` conservatively (2× expected p99 wall time) to catch runaway VMs without killing normal workloads
- **Pool sizing** — set ``ContainerPool`` size to match your maximum parallel agent concurrency; over-provisioning wastes memory, under-provisioning serializes requests
- **Monitor hooks** — wire ``ContainerHealthMonitor`` status changes into your Harness `AgentHookPipeline` so critical container events flow through your existing observability stack
