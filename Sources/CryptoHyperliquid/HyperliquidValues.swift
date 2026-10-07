// HyperliquidValues.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoOHLCV
import FOSFoundation
import Foundation

// § 5.1's inits and credentials: the credential is a typed, sealed value with no public getter, never a String; the
// client reads no file (AR32, T40). The endpoint follows the consumer's production setting and nothing else (AR45).

/// What ``HyperliquidClient`` signs with: an agent wallet the main wallet approved (T41)
///
/// ```swift
/// let client = HyperliquidClient(credential: .agentKey(key), endpoint: .testMarket)
/// ```
public enum HyperliquidCredential: Sendable {
    case agentKey(HyperliquidAgentKey)
}

/// Which Hyperliquid a client speaks to: its test market or production
public enum HyperliquidEndpoint: Hashable, Sendable {
    case testMarket
    case production

    var baseURL: URL {
        switch self {
        case .testMarket: URL(string: "https://api.hyperliquid-testnet.xyz")!
        case .production: URL(string: "https://api.hyperliquid.xyz")!
        }
    }

    var isMainnet: Bool {
        self == .production
    }
}

/// Hyperliquid's id for an order, its `oid`
///
/// ```swift
/// if case .filled(_, _, let id, _) = result { try await client.cancelOrder(id, market: btc, account: account) }
/// ```
public struct HyperliquidOrderId: Codable, Hashable, Sendable, Stubbable {
    package let oid: Int64

    /// The order Hyperliquid numbered `oid`
    public init(_ oid: Int64) {
        self.oid = oid
    }

    public init(from decoder: any Decoder) throws {
        self.oid = try decoder.singleValueContainer().decode(Int64.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(oid)
    }

    public static func stub() -> Self { .init(42) }
}

/// Where a read of Hyperliquid's ledger resumes: the millisecond of the last item read, and that item's place among
/// the items of its millisecond
///
/// Hyperliquid's ledger reads take a start time, inclusive, and two items can share a millisecond (two fills of one
/// order, the funding of several coins in one hour). The client hands up the items of one millisecond in one order,
/// the fills by Hyperliquid's trade id, then the funding by coin, then the other updates by hash, and the cursor
/// after an item names its millisecond and its place in that order, 1 for the first; a read from the cursor asks from
/// its millisecond and drops the items at or before its place, so an item is never lost and never comes twice while
/// Hyperliquid's answer for that millisecond is the same.
///
/// It encodes as `{"milliseconds": …, "place": …}`; the earlier form, the millisecond alone, decodes as place 0, a
/// read from the millisecond's first item.
public struct HyperliquidLedgerCursor: Codable, Hashable, Sendable, Stubbable {
    package let milliseconds: Int64
    /// The item's place among the items of its millisecond, 1 for the first; 0 before the first
    public let place: Int

    /// The instant the cursor names
    public var time: Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }

    package init(milliseconds: Int64, place: Int) {
        self.milliseconds = milliseconds
        self.place = place
    }

    private enum CodingKeys: String, CodingKey {
        case milliseconds, place
    }

    public init(from decoder: any Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self), keyed.contains(.milliseconds) {
            self.milliseconds = try keyed.decode(Int64.self, forKey: .milliseconds)
            self.place = try keyed.decode(Int.self, forKey: .place)
        } else {
            self.milliseconds = try decoder.singleValueContainer().decode(Int64.self)
            self.place = 0
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(milliseconds, forKey: .milliseconds)
        try container.encode(place, forKey: .place)
    }

    public static func stub() -> Self { .init(milliseconds: 42 * 86_400_000, place: 1) }
}

/// Hyperliquid's own refusal of a request: `{"status":"err","response":"User or API Wallet 0x… does not exist."}`
///
/// Decoded by FOSFoundation's fetch as its `errorType`; a body whose status is "ok" is not an error and does not
/// decode as one. ``HyperliquidClient`` maps it into ``ExchangeClientError`` and throws that: this type never reaches a caller.
public struct HyperliquidAPIError: Error, Decodable, Hashable, Sendable {
    /// Hyperliquid's words, as it wrote them
    public let text: String

    public init(text: String) {
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case status, response
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(String.self, forKey: .status) == "err" else {
            throw DecodingError.dataCorruptedError(forKey: .status, in: container, debugDescription: "A status other than err is not an error")
        }
        self.text = try container.decode(String.self, forKey: .response)
    }
}
