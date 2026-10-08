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

    /// - Throws: ``ExchangeClientError/unauthorized(text:)`` when either is empty or the secret is not base64
    public init(apiKey: String, base64Secret: String) throws {
        guard !apiKey.isEmpty, let secret = Data(base64Encoded: base64Secret), !secret.isEmpty else {
            throw ExchangeClientError.malformedCredential
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

    /// - Throws: ``ExchangeClientError/malformedResponse(text:)`` when `candidate` is empty, longer than 40
    ///   characters, or not ASCII letters, digits and dashes. Decoding the same text throws a `DecodingError` instead.
    public init(validating candidate: String) throws {
        guard Self.isWellFormed(candidate) else {
            throw ExchangeClientError.malformedOrderId(candidate)
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

/// Kraken's id for an item of an account's history: a trade's transaction id from TradesHistory ("THVRQM-33VKH-UCI7BS")
/// or a ledger entry's id from Ledgers ("L4UESK-KG3EQ-UFO4T5"), the key Kraken files the item under
///
/// Kraken's, never a value this package makes: a cursor names the items it has read by these.
public struct KrakenLedgerId: Codable, Hashable, Comparable, Sendable, Stubbable {
    package let text: String

    /// - Throws: ``ExchangeClientError/malformedResponse(text:)`` when `candidate` is empty, longer than 40
    ///   characters, or not ASCII letters, digits and dashes. Decoding the same text throws a `DecodingError` instead.
    public init(validating candidate: String) throws {
        guard Self.isWellFormed(candidate) else {
            throw ExchangeClientError.malformedOrderId(candidate)
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
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a Kraken ledger id: \"\(candidate)\"")
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
            return try .init(validating: "LFRED-BARNEY-42")
        } catch {
            preconditionFailure("KrakenLedgerId.stub() is not well-formed: \(error)")
        }
    }
}

/// Where a read of Kraken's ledger resumes: the oldest unmatched item, named by the ids Kraken gave the items read at
/// the cursor's own instant, never a time alone
///
/// A cursor is an instant to the ten-thousandth of a second and ``read``, the ids of every item at that instant already
/// handed up. Kraken's ledger and trade reads take a start time, exclusive; the client asks from the ten-thousandth
/// before the instant, so the instant's own items come back, and hands up those after the instant plus those at it
/// whose id the cursor does not name: none twice, none skipped. Kraken sends most times as JSON numbers, which the
/// client reads as a Double and rounds to four places; a time Kraken sends as text is kept as written.
///
/// It encodes as an object, `{"seconds": "…", "read": ["…"]}`. A cursor stored before it named items is the seconds
/// as bare text; it decodes as a cursor naming no item, which reads as "after the instant" as it always did.
public struct KrakenLedgerCursor: Codable, Hashable, Sendable, Stubbable {
    package let seconds: WireDecimal

    /// The ids of the items at the cursor's instant that have been read
    public let read: Set<KrakenLedgerId>

    /// The instant the cursor names
    public var time: Date {
        Date(timeIntervalSince1970: Double(seconds.digits) / Double(WireDecimal.powerOfTen(seconds.fractionDigits)))
    }

    package init(seconds: WireDecimal, read: Set<KrakenLedgerId> = []) {
        self.seconds = seconds
        self.read = read
    }

    private enum CodingKeys: String, CodingKey {
        case seconds, read
    }

    public init(from decoder: any Decoder) throws {
        if let bare = try? decoder.singleValueContainer().decode(String.self) {
            self.seconds = try WireDecimal(parsing: bare)
            self.read = []
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.seconds = try WireDecimal(parsing: container.decode(String.self, forKey: .seconds))
        self.read = Set(try container.decode([KrakenLedgerId].self, forKey: .read))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(seconds.text, forKey: .seconds)
        try container.encode(read.sorted(), forKey: .read)
    }

    public static func stub() -> Self { .init(seconds: WireDecimal(digits: 42 * 86_400, fractionDigits: 0), read: [.stub()]) }
}
