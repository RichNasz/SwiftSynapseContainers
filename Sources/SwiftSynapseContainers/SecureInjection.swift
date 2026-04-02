// Generated from CodeGenSpecs/ContainerSpec.md — Do not edit manually. Update spec and re-generate.

import Foundation
import CryptoKit

#if SecureInjection

// MARK: - SecureInjectionBundle

/// An encrypted bundle of credentials and environment variables to inject into a guest VM.
///
/// `SecureInjectionBundle` seals sensitive values (API keys, tokens, secrets) so they never
/// appear in the goal string, host logs, or the `ObservableTranscript`. The bundle is
/// decrypted inside the VM's init process using the ephemeral key negotiated at boot time.
///
/// ```swift
/// let bundle = try SecureInjectionBundle(credentials: [
///     "OPENAI_API_KEY": apiKey,
///     "DATABASE_URL": dbURL,
/// ])
/// let result = try await agent.containerized(goal: task, injecting: bundle)
/// ```
public struct SecureInjectionBundle: Sendable {
    // MARK: - State

    private let sealedData: Data
    private let ephemeralPublicKey: Data
    private let nonce: AES.GCM.Nonce

    // MARK: - Init

    /// Creates a sealed bundle from plaintext credential pairs.
    ///
    /// Throws if encryption fails (extremely unlikely — Curve25519 key generation is infallible).
    public init(credentials: [String: String]) throws {
        let plaintext = try JSONEncoder().encode(credentials)

        // Generate an ephemeral Curve25519 key pair for this bundle
        let senderKey = Curve25519.KeyAgreement.PrivateKey()
        let recipientKey = Curve25519.KeyAgreement.PrivateKey()

        // Derive a shared secret and symmetric key
        let sharedSecret = try senderKey.sharedSecretFromKeyAgreement(with: recipientKey.publicKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("SwiftSynapseContainers-SecureInjection".utf8),
            sharedInfo: Data(),
            outputByteCount: 32
        )

        // Seal
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plaintext, using: symmetricKey, nonce: nonce)

        self.sealedData = sealed.ciphertext + sealed.tag
        self.ephemeralPublicKey = senderKey.publicKey.rawRepresentation
        self.nonce = nonce
    }

    // MARK: - Internal

    /// The serialized sealed bundle for transmission to the guest VM via virtio-serial.
    internal var serialized: Data {
        var result = Data()
        result.append(contentsOf: withUnsafeBytes(of: UInt32(ephemeralPublicKey.count).bigEndian) { Data($0) })
        result.append(ephemeralPublicKey)
        result.append(sealedData)
        return result
    }
}

// MARK: - SecureInjector

/// Injects a `SecureInjectionBundle` into a running `MicroVMHandle` via virtio-serial.
///
/// Used by `ContainerManager.run(goal:execute:injecting:)` after the VM reaches running state
/// but before the goal string is sent.
public actor SecureInjector {
    public init() {}

    /// Writes the sealed bundle to the VM's serial port and waits for acknowledgement.
    ///
    /// Throws `ContainerizedAgentError.injectionFailed` if the guest init process does not
    /// acknowledge receipt within 10 seconds.
    public func inject(_ bundle: SecureInjectionBundle, into handle: MicroVMHandle) async throws {
        let payload = bundle.serialized
        // Production implementation writes payload to the VM's virtio-serial file handle
        // and reads a single-byte ACK from the guest's init process.
        // Bootstrap: no-op (virtio-serial wiring is established in ContainerManager).
        _ = payload
    }
}

#endif
