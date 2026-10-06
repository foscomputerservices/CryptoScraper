// KrakenValues.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoExchange
import CryptoOHLCV
import FOSFoundation
import Foundation

// § 5.1's inits and credentials (AR32): an API key and its secret, a typed, sealed value with no public getter; the
// client reads no file.

/// A Kraken API key and its secret, as Kraken issues them: the key's text and the secret's base64 text
///
/// Sealed: read by nothing but the client's signing. Its description and its reflection show neither.
///
/// ```swift
/// let credential = try KrakenCredential(apiKey: keyFromTheKeychain, base64Secret: secretFromTheKeychain)
/// let client = KrakenClient(credential: credential)
/// ```
public struct KrakenCredential: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    let apiKey: String
    let secret: Data

    /// - Throws: ``KrakenClientError/malformedCredential`` when either is empty or the secret is not base64
    public init(apiKey: String, base64Secret: String) throws {
        guard !apiKey.isEmpty, let secret = Data(base64Encoded: base64Secret), !secret.isEmpty else {
            throw KrakenClientError.malformedCredential
        }
        self.apiKey = apiKey
        self.secret = secret
    }

    public var description: String { "KrakenCredential(…)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// Kraken's id for an order, its transaction id: "OUF4EM-FRGI2-MQMWZD"
public struct KrakenOrderId: Codable, Hashable, Sendable, Stubbable {
    package let text: String

    /// - Throws: ``KrakenClientError/malformedOrderId(_:)`` when `candidate` is not ASCII letters, digits and dashes
    public init(validating candidate: String) throws {
        guard Self.isWellFormed(candidate) else {
            throw KrakenClientError.malformedOrderId(candidate)
        }
        self.text = candidate
    }

    private static func isWellFormed(_ candidate: String) -> Bool {
        !candidate.isEmpty && candidate.count <= 40 && candidate.unicodeScalars.allSatisfy {
            ("A"..."Z").contains($0) || ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-"
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let candidate = try container.decode(String.self)
        guard Self.isWellFormed(candidate) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a Kraken transaction id: \"\(candidate)\"")
        }
        self.text = candidate
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }

    public static func stub() -> Self {
        do {
            return try .init(validating: "OFRED-BARNEY-42")
        } catch {
            preconditionFailure("KrakenOrderId.stub() is not well-formed: \(error)")
        }
    }
}

/// Where a read of Kraken's ledger resumes: the time of the last item read, exactly as Kraken stated it
///
/// Kraken's ledger and trade reads take a start time, exclusive, to the ten-thousandth of a second it states.
public struct KrakenLedgerCursor: Codable, Hashable, Sendable, Stubbable {
    package let seconds: WireDecimal

    /// The instant the cursor names
    public var time: Date {
        Date(timeIntervalSince1970: Double(seconds.digits) / Double(WireDecimal.powerOfTen(seconds.fractionDigits)))
    }

    package init(seconds: WireDecimal) {
        self.seconds = seconds
    }

    public init(from decoder: any Decoder) throws {
        self.seconds = try WireDecimal(parsing: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(seconds.text)
    }

    public static func stub() -> Self { .init(seconds: WireDecimal(digits: 42 * 86_400, fractionDigits: 0)) }
}

/// Why ``KrakenClient`` could not do what was asked
public enum KrakenClientError: Error, Hashable, Sendable {
    /// An API key or a secret that is empty, or a secret that is not base64
    case malformedCredential
    /// A transaction id that is not one Kraken could write
    case malformedOrderId(String)
    /// A member that signs was asked of a client made without a credential
    case noCredential
    /// A market Kraken's AssetPairs does not list
    case unknownMarket(KrakenMarketName)
    /// An asset Kraken's Assets does not list
    case unknownAsset(String)
    /// A size or a price in an asset other than the market's
    case wrongAsset
    /// Kraken spot sets leverage on each order, never on a market or an account
    case leverageNotSettable
    /// Kraken spot offers no transfer between an account's own wallets through this API
    case transferNotOffered
    /// Kraken states no key's permissions or approval through its API
    case keyFactsNotOffered
    /// Kraken answered and did not do it, in its own words
    case refused(String)
}
