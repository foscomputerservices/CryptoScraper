// ExchangeMarketNames.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

// One market name per exchange, shared by the exchange's two public clients: its OHLCV client here (C32) and its
// exchange client in the exchange's plug-in library (C31), which imports this library for the name. So a consumer maps
// an asset to an exchange's market once, whichever client it then asks (R8).
//
// Each name is validated on the way in and has no string-literal door and no text out to a consumer: the clients of
// this package read it, through `package` access, to write a request. It encodes as the exchange's own spelling so a
// consumer can keep it.

/// A Hyperliquid market's name as Hyperliquid spells it in a request: "BTC", "kPEPE", "@107"
///
/// Hyperliquid's names are case-sensitive ("kPEPE" is a thousand PEPE), so the name is kept exactly as given.
///
/// ```swift
/// let btc = try HyperliquidMarketName(validating: "BTC")
/// let bars = try await HyperliquidOHLCVClient().ohlcv(market: btc, interval: .init(count: 4, unit: .hour), from: start, through: end)
/// ```
public struct HyperliquidMarketName: Codable, Hashable, Sendable, Stubbable {
    package let text: String

    /// - Throws: ``HyperliquidOHLCVError/malformedMarketName(_:)`` when `candidate` is empty, longer than 32
    ///   characters, or carries a character other than an ASCII letter, a digit, "@", ":", "/", "-" or "_"
    public init(validating candidate: String) throws {
        guard Self.isWellFormed(candidate) else {
            throw HyperliquidOHLCVError.malformedMarketName(candidate)
        }
        self.text = candidate
    }

    private static func isWellFormed(_ candidate: String) -> Bool {
        !candidate.isEmpty && candidate.count <= 32 && candidate.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "A"..."Z", "a"..."z", "0"..."9", "@", ":", "/", "-", "_": true
            default: false
            }
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let candidate = try container.decode(String.self)
        guard Self.isWellFormed(candidate) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a well-formed Hyperliquid market name: \"\(candidate)\"")
        }
        self.text = candidate
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

/// A Kraken market's name as Kraken spells it in a request: "XXBTZUSD", or its alternative "XBTUSD"
///
/// Upper-cased on the way in; one to twenty ASCII letters and digits.
///
/// ```swift
/// let xbtusd = try KrakenMarketName(validating: "XBTUSD")
/// ```
public struct KrakenMarketName: Codable, Hashable, Sendable, Stubbable {
    package let text: String

    /// - Throws: ``KrakenOHLCVError/malformedMarketName(_:)`` when `candidate` is empty, longer than twenty
    ///   characters, or carries a character other than an ASCII letter or digit
    public init(validating candidate: String) throws {
        guard let text = Self.normalized(candidate) else {
            throw KrakenOHLCVError.malformedMarketName(candidate)
        }
        self.text = text
    }

    private static func normalized(_ candidate: String) -> String? {
        let upper = candidate.uppercased()
        let wellFormed = !candidate.isEmpty && candidate.count <= 20 && upper.count == candidate.count
            && upper.unicodeScalars.allSatisfy { scalar in
                switch scalar {
                case "A"..."Z", "0"..."9": true
                default: false
                }
            }
        return wellFormed ? upper : nil
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let candidate = try container.decode(String.self)
        guard let text = Self.normalized(candidate) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a well-formed Kraken market name: \"\(candidate)\"")
        }
        self.text = text
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

/// A Coinbase product's id as Coinbase spells it in a request: "BTC-USD", "BTC-PERP-INTX"
///
/// Upper-cased on the way in; one to 32 ASCII letters, digits and dashes.
///
/// ```swift
/// let btcusd = try CoinbaseMarketName(validating: "BTC-USD")
/// ```
public struct CoinbaseMarketName: Codable, Hashable, Sendable, Stubbable {
    package let text: String

    /// - Throws: ``CoinbaseOHLCVError/malformedMarketName(_:)`` when `candidate` is empty, longer than 32
    ///   characters, or carries a character other than an ASCII letter, a digit or a dash
    public init(validating candidate: String) throws {
        guard let text = Self.normalized(candidate) else {
            throw CoinbaseOHLCVError.malformedMarketName(candidate)
        }
        self.text = text
    }

    private static func normalized(_ candidate: String) -> String? {
        let upper = candidate.uppercased()
        let wellFormed = !candidate.isEmpty && candidate.count <= 32 && upper.count == candidate.count
            && upper.unicodeScalars.allSatisfy { scalar in
                switch scalar {
                case "A"..."Z", "0"..."9", "-": true
                default: false
                }
            }
        return wellFormed ? upper : nil
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let candidate = try container.decode(String.self)
        guard let text = Self.normalized(candidate) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a well-formed Coinbase product id: \"\(candidate)\"")
        }
        self.text = text
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

// The fakes are self-marking: no exchange lists a FRED market.
extension HyperliquidMarketName {
    public static func stub() -> Self { .stub(text: "FRED") }

    public static func stub(text: String = "FRED") -> Self {
        do {
            return try .init(validating: text)
        } catch {
            preconditionFailure("HyperliquidMarketName.stub(text:) with a malformed name: \(error)")
        }
    }
}

extension KrakenMarketName {
    public static func stub() -> Self { .stub(text: "FREDBARNEY") }

    public static func stub(text: String = "FREDBARNEY") -> Self {
        do {
            return try .init(validating: text)
        } catch {
            preconditionFailure("KrakenMarketName.stub(text:) with a malformed name: \(error)")
        }
    }
}

extension CoinbaseMarketName {
    public static func stub() -> Self { .stub(text: "FRED-BARNEY") }

    public static func stub(text: String = "FRED-BARNEY") -> Self {
        do {
            return try .init(validating: text)
        } catch {
            preconditionFailure("CoinbaseMarketName.stub(text:) with a malformed name: \(error)")
        }
    }
}
