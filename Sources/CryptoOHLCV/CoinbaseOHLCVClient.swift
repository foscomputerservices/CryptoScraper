// CoinbaseOHLCVClient.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Coinbase Advanced Trade's OHLCV client: closed candles from the public `market/products/{id}/candles`, every
/// number decoded exactly
///
/// Each call is one request through FOSFoundation's fetch with ``CoinbaseAPIError`` as its error type, asking for the
/// candles whose start falls in the range (Coinbase answers up to 350, newest first; they are handed up oldest
/// first). The still-open candle is handed up only by ``openOHLCV(market:interval:)``;
/// ``ohlcv(market:interval:from:through:)`` hands up closed bars only.
///
/// ```swift
/// let client = CoinbaseOHLCVClient()
/// let btcusd = try CoinbaseMarketName(validating: "BTC-USD")
/// let days = try await client.ohlcv(market: btcusd, interval: .init(count: 1, unit: .day), from: start, through: end)
/// ```
///
/// A product's two holdings are Coinbase's declared constants (``CoinbaseHolding``), each of its currency ids in the
/// public `market/products/{id}` resolved through ``CoinbaseExchangeChain``'s table, once per product and kept for
/// the client's life. The product's increment for each is checked against the declared holding's decimals (AR45).
///
/// A 429 throws ``CoinbaseLimitError``; any other body Coinbase states as an error throws ``CoinbaseAPIError``;
/// number text that is not a number, or finer than a holding holds, throws ``AmountError``; a currency id the table
/// lacks, or whose holding the registry does not declare, throws `AssetError.malformedIdentity`; an increment finer
/// than the declared holding's decimals throws `AssetRegistryError.decimalsChanged` (a coarser one is accepted); an
/// interval Coinbase has no granularity for throws ``CoinbaseOHLCVError/unsupportedInterval(_:)``. When the init could
/// not add Coinbase's declarations to its registry, every read throws what `AssetRegistry.add(_:)` threw.
public struct CoinbaseOHLCVClient: OHLCVClient {
    public typealias MarketName = CoinbaseMarketName

    private let baseURL: URL
    private let session: any URLSessionProtocol
    private let now: @Sendable () -> Date
    private let products: CoinbaseProductBook
    private let registry: AssetRegistry
    // Coinbase's declarations added to the registry at init, or why they could not be: thrown by every read
    private let declared: Result<Void, any Error>

    /// - Parameters:
    ///   - baseURL: Coinbase's REST root
    ///   - session: The session the requests go through; a test passes a recorded one
    ///   - now: The clock that says whether a candle has closed
    ///   - registry: The statement every amount and price is read against; Coinbase's holdings are added to it here
    public init(
        baseURL: URL = URL(string: "https://api.coinbase.com")!,
        session: any URLSessionProtocol = URLSession.session(config: DataFetch<URLSession>.urlSessionConfiguration()),
        now: @escaping @Sendable () -> Date = { Date() },
        registry: AssetRegistry = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.now = now
        self.products = CoinbaseProductBook()
        self.registry = registry
        self.declared = Result { try CoinbaseExchangeChain.declare(in: registry) }
    }

    public func ohlcv(market: CoinbaseMarketName, interval: BarInterval, from: Date, through: Date) async throws -> [OHLCVClientBar] {
        let granularity = try Self.granularity(for: interval)
        // Coinbase counts in whole seconds: up from `from`, down from `through`, so the range is never widened.
        let start = Int64((from.timeIntervalSince1970).rounded(.up))
        let end = Int64((through.timeIntervalSince1970).rounded(.down))
        guard start <= end else { return [] }

        let product = try await self.product(market)
        let candles = try await self.candles(market, granularity, start, end)
        let clock = now().wireMilliseconds
        let seconds = interval.milliseconds / 1000
        return try candles
            .filter { $0.start >= start && $0.start <= end }
            .sorted { $0.start < $1.start }
            .map { try $0.bar(of: product, intervalSeconds: seconds, now: clock, in: registry) }
            .filter(\.isClosed)
    }

    public func openOHLCV(market: CoinbaseMarketName, interval: BarInterval) async throws -> OHLCVClientBar? {
        let granularity = try Self.granularity(for: interval)
        let product = try await self.product(market)
        let clock = now().wireMilliseconds
        let seconds = interval.milliseconds / 1000
        let candles = try await self.candles(market, granularity, clock / 1000 - 2 * seconds, clock / 1000)
        guard let newest = candles.max(by: { $0.start < $1.start }) else {
            return nil
        }
        let bar = try newest.bar(of: product, intervalSeconds: seconds, now: clock, in: registry)
        return bar.isClosed ? nil : bar
    }

    // Coinbase's granularities: 1, 5, 15 and 30 minutes; 1, 2, 4 and 6 hours; 1 day.
    static func granularity(for interval: BarInterval) throws -> String {
        let token: String? = switch (interval.unit, interval.count) {
        case (.minute, 1): "ONE_MINUTE"
        case (.minute, 5): "FIVE_MINUTE"
        case (.minute, 15): "FIFTEEN_MINUTE"
        case (.minute, 30): "THIRTY_MINUTE"
        case (.hour, 1): "ONE_HOUR"
        case (.hour, 2): "TWO_HOUR"
        case (.hour, 4): "FOUR_HOUR"
        case (.hour, 6): "SIX_HOUR"
        case (.day, 1): "ONE_DAY"
        default: nil
        }
        guard let token else {
            throw CoinbaseOHLCVError.unsupportedInterval(interval)
        }
        return token
    }

    // The product's two declared holdings, through the table, each checked against the product's increment (AR45).
    private func product(_ market: CoinbaseMarketName) async throws -> CoinbaseProductAssets {
        try declared.get()
        if let known = await products.product(market) {
            return known
        }
        let info: CoinbaseProductInfo = try await get("/api/v3/brokerage/market/products/\(market.text)", [])
        let product = try info.holdings(in: registry)
        await products.keep(product, as: market)
        return product
    }

    private func candles(_ market: CoinbaseMarketName, _ granularity: String, _ start: Int64, _ end: Int64) async throws -> [CoinbaseCandle] {
        let answer: CoinbaseCandles = try await get("/api/v3/brokerage/market/products/\(market.text)/candles", [
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "end", value: String(end)),
            URLQueryItem(name: "granularity", value: granularity)
        ])
        return answer.candles
    }

    private func get<Value: Decodable & Sendable>(_ path: String, _ query: [URLQueryItem]) async throws -> Value {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else {
            throw DataFetchError.badURL("\(path) \(query)")
        }
        return try await ClientFetch.send(url, session: session, errorType: CoinbaseAPIError.self, errorForResponse: Self.limitError(for:body:))
    }

    // Coinbase's limit as CoinbaseLimitError: HTTP 429; nil for every other response, which the fetch reads.
    package static func limitError(for response: HTTPURLResponse, body: Data?) -> (any Error)? {
        guard response.statusCode == 429 else {
            return nil
        }
        return CoinbaseLimitError(retryAfter: WireResponse.retryAfter(response), apiError: WireResponse.decoded(body, as: CoinbaseAPIError.self))
    }
}

/// Why ``CoinbaseOHLCVClient`` could not hand up what was asked, where Coinbase itself said nothing wrong
public enum CoinbaseOHLCVError: Error, Hashable, Sendable {
    /// Coinbase has no candle granularity of this length: 1, 5, 15 and 30 minutes; 1, 2, 4 and 6 hours; 1 day
    case unsupportedInterval(BarInterval)
    /// A product id that is not one Coinbase could spell
    case malformedMarketName(String)
}

// A product's two declared holdings.
package struct CoinbaseProductAssets: Sendable {
    package let base: AssetInstance
    package let quote: AssetInstance
}

private actor CoinbaseProductBook {
    private var byName: [CoinbaseMarketName: CoinbaseProductAssets] = [:]

    func product(_ market: CoinbaseMarketName) -> CoinbaseProductAssets? {
        byName[market]
    }

    func keep(_ product: CoinbaseProductAssets, as market: CoinbaseMarketName) {
        byName[market] = product
    }
}

// MARK: Response models

// The part of a product this client reads: its two currencies and their increments, checked against the declared
// holdings' decimals.
package struct CoinbaseProductInfo: Decodable, Sendable {
    package let baseCurrencyId: String
    package let quoteCurrencyId: String
    package let baseIncrement: WireDecimal
    package let quoteIncrement: WireDecimal

    private enum CodingKeys: String, CodingKey {
        case baseCurrencyId = "base_currency_id"
        case quoteCurrencyId = "quote_currency_id"
        case baseIncrement = "base_increment"
        case quoteIncrement = "quote_increment"
    }

    // Each currency's declared holding through the table, its increment's places ("0.00000001" is 8) checked against
    // the declared decimals, only a finer one refused; a currency id the table lacks, or a holding not declared, is a
    // finding, thrown as AssetError.malformedIdentity.
    package func holdings(in registry: AssetRegistry) throws -> CoinbaseProductAssets {
        guard let base = try CoinbaseExchangeChain.declaredInstance(wireName: baseCurrencyId, decimals: baseIncrement.fractionDigits, in: registry) else {
            throw AssetError.malformedIdentity(baseCurrencyId)
        }
        guard let quote = try CoinbaseExchangeChain.declaredInstance(wireName: quoteCurrencyId, decimals: quoteIncrement.fractionDigits, in: registry) else {
            throw AssetError.malformedIdentity(quoteCurrencyId)
        }
        return CoinbaseProductAssets(base: base, quote: quote)
    }
}

struct CoinbaseCandles: Decodable, Sendable {
    let candles: [CoinbaseCandle]
}

// One candle as Coinbase sends it: {"start":"<unix seconds>","low":"…","high":"…","open":"…","close":"…","volume":"…"}
// Every number is text, the start too; each is decoded here exactly.
struct CoinbaseCandle: Decodable, Sendable {
    let start: Int64
    let low: WireDecimal
    let high: WireDecimal
    let open: WireDecimal
    let close: WireDecimal
    let volume: WireDecimal

    private enum CodingKeys: String, CodingKey {
        case start, low, high, open, close, volume
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let startText = try container.decode(String.self, forKey: .start)
        guard let start = Int64(startText) else {
            throw DecodingError.dataCorruptedError(forKey: .start, in: container, debugDescription: "A candle's start that is not whole seconds: \"\(startText)\"")
        }
        self.start = start
        self.low = try container.decode(WireDecimal.self, forKey: .low)
        self.high = try container.decode(WireDecimal.self, forKey: .high)
        self.open = try container.decode(WireDecimal.self, forKey: .open)
        self.close = try container.decode(WireDecimal.self, forKey: .close)
        self.volume = try container.decode(WireDecimal.self, forKey: .volume)
    }

    // The bar: Coinbase states no close time, so it is the start plus the interval less one millisecond; closed once
    // the clock has passed it. Coinbase states no count of trades.
    func bar(of product: CoinbaseProductAssets, intervalSeconds: Int64, now: Int64, in registry: AssetRegistry) throws -> OHLCVClientBar {
        let closeTime = (start + intervalSeconds) * 1000 - 1
        return OHLCVClientBar(
            openTime: Date(wireMilliseconds: start * 1000),
            closeTime: Date(wireMilliseconds: closeTime),
            open: try open.price(of: product.quote, per: product.base, in: registry),
            high: try high.price(of: product.quote, per: product.base, in: registry),
            low: try low.price(of: product.quote, per: product.base, in: registry),
            close: try close.price(of: product.quote, per: product.base, in: registry),
            volume: try volume.amount(of: product.base, in: registry),
            trades: nil,
            isClosed: now > closeTime
        )
    }
}
