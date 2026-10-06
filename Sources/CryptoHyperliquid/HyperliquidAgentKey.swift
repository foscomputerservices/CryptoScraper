// HyperliquidAgentKey.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoSwift
import Foundation
import secp256k1

// AR33: the agent key signs every order, cancel, leverage change and sub-account transfer; secp256k1 over a
// Keccak-256 hash, on secp256k1.swift and CryptoSwift (swift-crypto carries neither). T40: the key never leaves this
// value: no property vends it, its description and its reflection name no byte of it, and nothing here writes it.

/// A Hyperliquid agent wallet's private key: the key the main wallet approved, which signs for it
///
/// Sealed: made once from the key's 32 bytes, read by nothing but the client's signing. Its description and its
/// reflection show no part of the key.
///
/// ```swift
/// let key = try HyperliquidAgentKey(privateKey: bytesFromTheKeychain)
/// let client = HyperliquidClient(credential: .agentKey(key), endpoint: .testMarket)
/// ```
public struct HyperliquidAgentKey: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    private let secret: [UInt8]
    /// The agent's address, lower-case hex with its "0x", derived from the key
    package let address: String

    /// - Throws: ``HyperliquidClientError/malformedAgentKey`` when `privateKey` is not 32 bytes or is not a valid
    ///   secp256k1 secret
    public init(privateKey: Data) throws {
        let bytes = [UInt8](privateKey)
        guard bytes.count == 32, let address = Self.address(of: bytes) else {
            throw HyperliquidClientError.malformedAgentKey
        }
        self.secret = bytes
        self.address = address
    }

    public var description: String { "HyperliquidAgentKey(\(address))" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["address": address]) }

    /// The recoverable signature of a 32-byte digest: r, s and v as Ethereum writes them (v is 27 or 28)
    ///
    /// libsecp256k1's default nonce is RFC 6979's, deterministic, and its signature's s is the lower of the two, as
    /// viem's is, so the same digest signs to the same bytes as the POC's SDK.
    package func sign(digest: [UInt8]) -> (r: [UInt8], s: [UInt8], v: Int) {
        precondition(digest.count == 32, "HyperliquidAgentKey.sign(digest:) with a digest that is not 32 bytes")
        let context = Self.context
        var signature = secp256k1_ecdsa_recoverable_signature()
        let signed = secret.withUnsafeBufferPointer { key in
            digest.withUnsafeBufferPointer { message in
                secp256k1_ecdsa_sign_recoverable(context, &signature, message.baseAddress!, key.baseAddress!, nil, nil)
            }
        }
        precondition(signed == 1, "libsecp256k1 refused to sign with a key it accepted")
        var compact = [UInt8](repeating: 0, count: 64)
        var recovery: Int32 = 0
        _ = secp256k1_ecdsa_recoverable_signature_serialize_compact(context, &compact, &recovery, &signature)
        return (Array(compact[0..<32]), Array(compact[32..<64]), 27 + Int(recovery))
    }

    // The address: the last 20 bytes of the Keccak-256 of the uncompressed public key without its prefix byte.
    private static func address(of secret: [UInt8]) -> String? {
        let context = Self.context
        guard secret.withUnsafeBufferPointer({ secp256k1_ec_seckey_verify(context, $0.baseAddress!) }) == 1 else {
            return nil
        }
        var publicKey = secp256k1_pubkey()
        guard secret.withUnsafeBufferPointer({ secp256k1_ec_pubkey_create(context, &publicKey, $0.baseAddress!) }) == 1 else {
            return nil
        }
        var serialized = [UInt8](repeating: 0, count: 65)
        var length = 65
        _ = secp256k1_ec_pubkey_serialize(context, &serialized, &length, &publicKey, UInt32(SECP256K1_EC_UNCOMPRESSED))
        let hash = SHA3(variant: .keccak256).calculate(for: Array(serialized[1..<65]))
        return "0x" + hash.suffix(20).toHexString()
    }

    // One context for signing and verifying, made once; libsecp256k1's contexts are safe to share once made.
    nonisolated(unsafe) private static let context: OpaquePointer = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!
}
