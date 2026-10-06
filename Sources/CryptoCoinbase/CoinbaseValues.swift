// CoinbaseValues.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoExchange
import CryptoOHLCV
import FOSFoundation
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// § 5.1's inits and credentials: a typed, sealed value with no public getter; the client reads no file.
//
// AR32 says Coinbase takes "an API key and a secret" with "an HMAC on each request". Coinbase Advanced Trade expired
// its HMAC (legacy) keys in February 2025; its CDP keys sign a JWT with ES256 per request (its authentication guide,
// 2026-10-06). The client speaks what the exchange accepts: the key's name and its EC private key, a JWT per request.
// A reading for the owner's pen.

/// A Coinbase CDP API key: its name and its EC (P-256) private key in PEM, as Coinbase issues them
///
/// Sealed: read by nothing but the client's signing. Its description and its reflection show neither.
///
/// ```swift
/// let credential = try CoinbaseCredential(keyName: nameFromTheKeychain, privateKeyPEM: pemFromTheKeychain)
/// let client = CoinbaseClient(credential: credential)
/// ```
public struct CoinbaseCredential: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    let keyName: String
    let key: P256.Signing.PrivateKey

    /// - Throws: ``CoinbaseClientError/malformedCredential`` when the name is empty or the PEM is not a P-256 key
    public init(keyName: String, privateKeyPEM: String) throws {
        guard !keyName.isEmpty else {
            throw CoinbaseClientError.malformedCredential
        }
        do {
            self.key = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        } catch {
            throw CoinbaseClientError.malformedCredential
        }
        self.keyName = keyName
    }

    public var description: String { "CoinbaseCredential(…)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// Coinbase's id for an order
public struct CoinbaseOrderId: Codable, Hashable, Sendable, Stubbable {
    package let text: String

    /// - Throws: ``CoinbaseClientError/malformedOrderId(_:)`` when `candidate` is not ASCII letters, digits and dashes
    public init(validating candidate: String) throws {
        guard Self.isWellFormed(candidate) else {
            throw CoinbaseClientError.malformedOrderId(candidate)
        }
        self.text = candidate
    }

    private static func isWellFormed(_ candidate: String) -> Bool {
        !candidate.isEmpty && candidate.count <= 64 && candidate.unicodeScalars.allSatisfy {
            ("A"..."Z").contains($0) || ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-"
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let candidate = try container.decode(String.self)
        guard Self.isWellFormed(candidate) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a Coinbase order id: \"\(candidate)\"")
        }
        self.text = candidate
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }

    public static func stub() -> Self {
        do {
            return try .init(validating: "fred-barney-42")
        } catch {
            preconditionFailure("CoinbaseOrderId.stub() is not well-formed: \(error)")
        }
    }
}

/// Where a read of Coinbase's fills resumes: the sequence time of the last fill read, exactly as Coinbase wrote it
public struct CoinbaseLedgerCursor: Codable, Hashable, Sendable, Stubbable {
    package let sequenceTimestamp: String

    /// The instant the cursor names, to the millisecond
    public var time: Date {
        CoinbaseTime.date(sequenceTimestamp) ?? .distantPast
    }

    /// - Throws: ``CoinbaseClientError/malformedCursor(_:)`` when the text is not an RFC 3339 time
    package init(sequenceTimestamp: String) throws {
        guard CoinbaseTime.date(sequenceTimestamp) != nil else {
            throw CoinbaseClientError.malformedCursor(sequenceTimestamp)
        }
        self.sequenceTimestamp = sequenceTimestamp
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard CoinbaseTime.date(text) != nil else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an RFC 3339 time: \"\(text)\"")
        }
        self.sequenceTimestamp = text
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(sequenceTimestamp)
    }

    public static func stub() -> Self {
        do {
            return try .init(sequenceTimestamp: "1970-02-12T00:00:00Z")
        } catch {
            preconditionFailure("CoinbaseLedgerCursor.stub() is not well-formed: \(error)")
        }
    }
}

/// Why ``CoinbaseClient`` could not do what was asked
public enum CoinbaseClientError: Error, Hashable, Sendable {
    /// A key name that is empty, or a private key that is not a P-256 key in PEM
    case malformedCredential
    /// An order id that is not one Coinbase could write
    case malformedOrderId(String)
    /// A cursor that is not an RFC 3339 time
    case malformedCursor(String)
    /// A member that signs was asked of a client made without a credential
    case noCredential
    /// A size or a price in an asset other than the product's, or a transfer of an asset that is not one
    case wrongAsset
    /// Coinbase Advanced Trade sets no leverage on a market or an account
    case leverageNotSettable
    /// Coinbase answered and did not do it, in its own words
    case refused(String)
}

// RFC 3339 times as Coinbase writes them, with or without fractional seconds.
enum CoinbaseTime {
    static func date(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) { return date }
        let whole = ISO8601DateFormatter()
        whole.formatOptions = [.withInternetDateTime]
        return whole.date(from: text)
    }
}
