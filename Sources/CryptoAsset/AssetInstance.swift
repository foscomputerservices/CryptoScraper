// AssetInstance.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// One contract on one chain, one holding on one exchange, or a fiat, as CryptoScraper's `CryptoContract.id`
/// states it
///
/// Used wherever a quantity is counted: every amount is counted in exactly one instance, at that instance's
/// decimals. Made from a contract or a fiat in CryptoScraper, or decoded from a stored row; never made up here.
///
/// ```swift
/// let usdt = AssetInstance(BinanceHolding(address: "USDT"))
/// usdt.id                          // "exchange:binance:USDT"
/// ```
public struct AssetInstance: Codable, Hashable, Identifiable, Sendable, Stubbable {
    /// `chain.id + ":" + address`, or a fiat's id
    public let id: String

    /// The chain's or exchange's id, the part before the last ":"; `nil` for a fiat
    public var chainId: String? {
        Self.split(id)?.chainId
    }

    /// The contract's address, the part after the last ":"; `nil` for a fiat
    public var address: String? {
        Self.split(id)?.address
    }

    /// - Throws: ``AssetError/malformedIdentity(_:)`` when `id` is not a CAIP-2-shaped chain id and an address,
    ///   or an `iso4217` code
    public init(validating id: String) throws {
        guard Self.isWellFormed(id) else {
            throw AssetError.malformedIdentity(id)
        }
        self.id = id
    }

    // MARK: Codable

    // An instance encodes as its id alone, one JSON string, and decodes through the validating initializer, so a
    // malformed id in a stored row is a DecodingError and never a value inside.

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let candidate = try container.decode(String.self)
        do {
            try self.init(validating: candidate)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Not a well-formed asset instance: \"\(candidate)\" (\(error))"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

// MARK: Stubs

extension AssetInstance {
    /// A holding on a reserved-fake chain, for a test that does not care which
    public static func stub() -> Self { .stub(chainId: "bedrock:42") }

    /// A stub on any chain id and address, every other piece a self-marking fake
    public static func stub(chainId: String = "bedrock:42", address: String = "quarry-42") -> Self {
        do {
            return try AssetInstance(validating: chainId + ":" + address)
        } catch {
            preconditionFailure("AssetInstance.stub(…) with a malformed identity: \(error)")
        }
    }
}

private extension AssetInstance {
    // The one place the rule for a well-formed identity lives (design § 1.2, § 1.4, § 1.5). A fiat is the
    // `iso4217` namespace and a code of three capital letters. Anything else is a CAIP-2 chain id, a namespace of 3
    // to 8 of [-a-z0-9] and a reference of 1 to 32 of [-_a-zA-Z0-9], then ":" and a non-empty address, split at the
    // last colon. The address's own grammar is its chain's (`contract(for:)`), so here it is only non-empty.

    static let fiatNamespace = ISO4217.namespace

    static func isWellFormed(_ id: String) -> Bool {
        if id.hasPrefix(fiatNamespace + ":") {
            return isISO4217Code(id.dropFirst(fiatNamespace.count + 1))
        }
        guard let (chainId, address) = split(id), !address.isEmpty else {
            return false
        }
        return isCAIP2ChainId(chainId)
    }

    static func split(_ id: String) -> (chainId: String, address: String)? {
        guard !id.hasPrefix(fiatNamespace + ":"), let lastColon = id.lastIndex(of: ":") else {
            return nil
        }
        return (String(id[..<lastColon]), String(id[id.index(after: lastColon)...]))
    }

    static func isISO4217Code(_ code: Substring) -> Bool {
        code.count == 3 && code.unicodeScalars.allSatisfy { ("A"..."Z").contains($0) }
    }

    static func isCAIP2ChainId(_ chainId: String) -> Bool {
        let parts = chainId.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return false
        }
        let namespace = parts[0]
        let reference = parts[1]
        return (3...8).contains(namespace.count)
            && namespace.unicodeScalars.allSatisfy { scalar in
                switch scalar {
                case "a"..."z", "0"..."9", "-": true
                default: false
                }
            }
            && (1...32).contains(reference.count)
            && reference.unicodeScalars.allSatisfy { scalar in
                switch scalar {
                case "a"..."z", "A"..."Z", "0"..."9", "-", "_": true
                default: false
                }
            }
    }
}
