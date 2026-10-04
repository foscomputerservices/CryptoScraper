// BinanceMarket.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation

/// A Binance spot market's name, as Binance spells it in a request: "BTCUSDT"
///
/// Validated on the way in, upper-cased, as ``AssetSymbol`` is: one to twenty ASCII letters and digits. There is no
/// string literal door; the validating initializer is the one way in and `text` the one way out.
///
/// ```swift
/// let market = try BinanceMarketName(validating: "btcusdt")     // "BTCUSDT"
/// let bars = try await client.ohlcv(market: market, interval: .init(count: 1, unit: .day), from: start, through: end)
/// ```
public struct BinanceMarketName: Codable, Hashable, Sendable, CustomStringConvertible, Stubbable {
    /// The market's name, upper-cased
    public let text: String

    /// - Throws: ``BinanceOHLCVError/malformedMarketName(_:)`` when `candidate` is empty, longer than twenty
    ///   characters, or carries a character other than an ASCII letter or digit
    public init(validating candidate: String) throws {
        self.text = try Self.normalized(candidate)
    }

    public var description: String {
        text
    }

    private static func normalized(_ candidate: String) throws -> String {
        let upper = candidate.uppercased()
        let wellFormed = !candidate.isEmpty && candidate.count <= 20 && upper.count == candidate.count
            && upper.unicodeScalars.allSatisfy { scalar in
                switch scalar {
                case "A"..."Z", "0"..."9": true
                default: false
                }
            }
        guard wellFormed else {
            throw BinanceOHLCVError.malformedMarketName(candidate)
        }
        return upper
    }

    // MARK: Codable

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let candidate = try container.decode(String.self)
        do {
            self.text = try Self.normalized(candidate)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Not a well-formed Binance market name: \"\(candidate)\""
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

/// A Binance spot market: its name and the two assets it trades, as Binance states them
///
/// The base asset is what a bar's volume counts; the quote asset is what its prices are in. Binance states each
/// asset's precision in `/api/v3/exchangeInfo`, and that precision is the asset's unit exponent here. A caller that
/// declares its assets with their unit names passes the markets in; otherwise ``BinanceOHLCVClient`` asks Binance
/// once per market.
///
/// ```swift
/// let btcusdt = BinanceMarket(name: try .init(validating: "BTCUSDT"), base: btc, quote: usdt)
/// let client = BinanceOHLCVClient(markets: [btcusdt])
/// ```
public struct BinanceMarket: Codable, Hashable, Sendable, Stubbable {
    public let name: BinanceMarketName
    public let base: Asset
    public let quote: Asset

    public init(name: BinanceMarketName, base: Asset, quote: Asset) {
        self.name = name
        self.base = base
        self.quote = quote
    }
}
