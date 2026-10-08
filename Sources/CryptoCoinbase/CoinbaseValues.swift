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

    /// - Throws: ``ExchangeClientError/unauthorized(text:)`` when the name is empty or the PEM is not a P-256 key
    public init(keyName: String, privateKeyPEM: String) throws {
        guard !keyName.isEmpty else {
            throw ExchangeClientError.malformedCredential
        }
        do {
            self.key = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        } catch {
            throw ExchangeClientError.malformedCredential
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

    /// - Throws: ``ExchangeClientError/malformedResponse(text:)`` when `candidate` is empty, longer than 64 characters, or not ASCII letters, digits and dashes
    public init(validating candidate: String) throws {
        guard Self.isWellFormed(candidate) else {
            throw ExchangeClientError.malformedOrderId(candidate)
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

/// Coinbase's id for a trade, the `trade_id` of a fill
///
/// Coinbase's, never a value this package makes: a cursor names the fills it has read by these.
public struct CoinbaseTradeId: Codable, Hashable, Comparable, Sendable, Stubbable {
    package let text: String

    /// - Throws: ``ExchangeClientError/malformedResponse(text:)`` when `candidate` is empty, longer than 64
    ///   characters, or holds anything but printable ASCII without spaces. Decoding the same text throws a
    ///   `DecodingError` instead.
    public init(validating candidate: String) throws {
        guard Self.isWellFormed(candidate) else {
            throw ExchangeClientError.malformedTradeId(candidate)
        }
        self.text = candidate
    }

    private static func isWellFormed(_ candidate: String) -> Bool {
        !candidate.isEmpty && candidate.count <= 64 && candidate.unicodeScalars.allSatisfy { ("!"..."~").contains($0) }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let candidate = try container.decode(String.self)
        guard Self.isWellFormed(candidate) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a Coinbase trade id: \"\(candidate)\"")
        }
        self.text = candidate
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.text < rhs.text }

    public static func stub() -> Self {
        do {
            return try .init(validating: "fred-barney-42")
        } catch {
            preconditionFailure("CoinbaseTradeId.stub() is not well-formed: \(error)")
        }
    }
}

/// Where a read of Coinbase's fills resumes: the oldest unmatched fill, named by the trade ids of the fills read at the
/// cursor's own sequence time, never a time alone
///
/// A cursor is a sequence time exactly as Coinbase wrote it and ``read``, the trade ids of every fill at that time
/// already handed up. List Fills includes the fill at its start; the client hands up the fills after the time plus
/// those at it whose trade id the cursor does not name: none twice, none skipped.
///
/// It encodes as an object, `{"sequenceTimestamp": "…", "read": ["…"]}`. A cursor stored before it named fills is the
/// RFC 3339 text alone; it decodes as a cursor naming no fill, which reads as "after the time" as it always did.
/// Decoding refuses a time that is not RFC 3339.
public struct CoinbaseLedgerCursor: Codable, Hashable, Sendable, Stubbable {
    package let sequenceTimestamp: String

    /// The trade ids of the fills at the cursor's time that have been read
    public let read: Set<CoinbaseTradeId>

    /// The instant the cursor names, with the fractional seconds Coinbase wrote
    public var time: Date {
        CoinbaseTime.date(sequenceTimestamp) ?? .distantPast
    }

    /// - Throws: ``ExchangeClientError/malformedResponse(text:)`` when the text is not an RFC 3339 time
    package init(sequenceTimestamp: String, read: Set<CoinbaseTradeId> = []) throws {
        guard CoinbaseTime.date(sequenceTimestamp) != nil else {
            throw ExchangeClientError.malformedCursor(sequenceTimestamp)
        }
        self.sequenceTimestamp = sequenceTimestamp
        self.read = read
    }

    private enum CodingKeys: String, CodingKey {
        case sequenceTimestamp, read
    }

    public init(from decoder: any Decoder) throws {
        if let bare = try? decoder.singleValueContainer().decode(String.self) {
            guard CoinbaseTime.date(bare) != nil else {
                throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Not an RFC 3339 time: \"\(bare)\"")
            }
            self.sequenceTimestamp = bare
            self.read = []
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decode(String.self, forKey: .sequenceTimestamp)
        guard CoinbaseTime.date(text) != nil else {
            throw DecodingError.dataCorruptedError(forKey: .sequenceTimestamp, in: container, debugDescription: "Not an RFC 3339 time: \"\(text)\"")
        }
        self.sequenceTimestamp = text
        self.read = Set(try container.decode([CoinbaseTradeId].self, forKey: .read))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sequenceTimestamp, forKey: .sequenceTimestamp)
        try container.encode(read.sorted(), forKey: .read)
    }

    public static func stub() -> Self {
        do {
            return try .init(sequenceTimestamp: "1970-02-12T00:00:00Z", read: [.stub()])
        } catch {
            preconditionFailure("CoinbaseLedgerCursor.stub() is not well-formed: \(error)")
        }
    }
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
