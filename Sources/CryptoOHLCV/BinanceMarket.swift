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

extension BinanceMarketName {
    public static func stub() -> Self { .stub(text: "FREDBARNEY") }

    public static func stub(text: String = "FREDBARNEY") -> Self {
        do {
            return try BinanceMarketName(validating: text)
        } catch {
            preconditionFailure("BinanceMarketName.stub(text:) with a malformed name: \(error)")
        }
    }
}

/// A Binance spot market: its name, what Binance calls its base and its quote with the precision it states for each,
/// and Binance's declared holdings for them
///
/// The holdings come through ``BinanceExchangeChain``'s table, never from Binance's names: a name the table lacks,
/// or a holding the registry does not declare, gives `nil`, with Binance's names and precision kept as facts (design
/// § 5.3). The precision Binance states in `/api/v3/exchangeInfo` is checked against the declared holding's decimals
/// (AR45). The base holding is what a bar's volume counts; the quote holding is what its prices are in. A caller that
/// holds Binance's exchange information passes the markets in; otherwise ``BinanceOHLCVClient`` asks Binance once
/// per market.
///
/// ```swift
/// let btcusdt = try BinanceMarket(name: try .init(validating: "BTCUSDT"), baseSymbol: try .init(validating: "BTC"),
///                                 baseDecimals: 8, quoteSymbol: try .init(validating: "USDT"), quoteDecimals: 8)
/// btcusdt.quote                            // AssetInstance(BinanceHolding.usdt): "exchange:binance:USDT"
/// let client = BinanceOHLCVClient(markets: [btcusdt])
/// ```
public struct BinanceMarket: Codable, Hashable, Sendable, Stubbable {
    public let name: BinanceMarketName
    /// What Binance calls the base, and the precision it states for it
    public let baseSymbol: AssetSymbol
    public let baseDecimals: Int
    /// What Binance calls the quote, and the precision it states for it
    public let quoteSymbol: AssetSymbol
    public let quoteDecimals: Int
    /// The declared holding on Binance's exchange chain; `nil` where nothing is declared
    public let base: AssetInstance?
    /// The declared holding on Binance's exchange chain; `nil` where nothing is declared
    public let quote: AssetInstance?

    /// The market Binance's exchange information states: each of its two names resolved through
    /// ``BinanceExchangeChain``'s table, Binance's declarations first added to `registry`
    ///
    /// - Throws: `AssetRegistryError.decimalsChanged` when Binance states another precision than a declared
    ///   holding's decimals (the units check, AR45); what `AssetRegistry.add(_:)` throws when `registry` states a
    ///   Binance holding otherwise
    public init(name: BinanceMarketName, baseSymbol: AssetSymbol, baseDecimals: Int, quoteSymbol: AssetSymbol,
                quoteDecimals: Int, in registry: AssetRegistry = .shared) throws {
        try BinanceExchangeChain.declare(in: registry)
        self.init(
            name: name, baseSymbol: baseSymbol, baseDecimals: baseDecimals, quoteSymbol: quoteSymbol, quoteDecimals: quoteDecimals,
            base: try BinanceExchangeChain.declaredInstance(wireName: baseSymbol.text, decimals: baseDecimals, in: registry),
            quote: try BinanceExchangeChain.declaredInstance(wireName: quoteSymbol.text, decimals: quoteDecimals, in: registry)
        )
    }

    // The resolved market as it is, for the stub; never made from a caller's instances.
    private init(name: BinanceMarketName, baseSymbol: AssetSymbol, baseDecimals: Int, quoteSymbol: AssetSymbol,
                 quoteDecimals: Int, base: AssetInstance?, quote: AssetInstance?) {
        self.name = name
        self.baseSymbol = baseSymbol
        self.baseDecimals = baseDecimals
        self.quoteSymbol = quoteSymbol
        self.quoteDecimals = quoteDecimals
        self.base = base
        self.quote = quote
    }
}

extension BinanceMarket {
    public static func stub() -> Self { .stub(name: .stub()) }

    /// FREDBARNEY: BARNEY at 4 on FRED at 4, its holdings Price's stub base and quote, on the reserved fake chain
    public static func stub(
        name: BinanceMarketName = .stub(),
        baseSymbol: AssetSymbol = .stub(text: "BARNEY"),
        baseDecimals: Int = 4,
        quoteSymbol: AssetSymbol = .stub(),
        quoteDecimals: Int = 4,
        base: AssetInstance? = Price.stub().base,
        quote: AssetInstance? = Price.stub().quote
    ) -> Self {
        .init(name: name, baseSymbol: baseSymbol, baseDecimals: baseDecimals, quoteSymbol: quoteSymbol,
              quoteDecimals: quoteDecimals, base: base, quote: quote)
    }
}
