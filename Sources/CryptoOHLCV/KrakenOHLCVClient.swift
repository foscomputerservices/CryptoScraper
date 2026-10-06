// KrakenOHLCVClient.swift
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

/// Kraken spot's OHLCV client: closed bars from `/0/public/OHLC`, every number decoded exactly
///
/// Each call is one request through FOSFoundation's fetch with ``KrakenAPIError`` as its error type. Kraken answers
/// at most its latest 720 bars of an interval, whatever the range asked: a range older than those is answered with
/// what Kraken still holds, which may be nothing. The still-open bar, which Kraken always sends last, is handed up only
/// by ``openOHLCV(market:interval:)``; ``ohlcv(market:interval:from:through:)`` hands up closed bars only.
///
/// ```swift
/// let client = KrakenOHLCVClient()
/// let xbtusd = try KrakenMarketName(validating: "XBTUSD")
/// let days = try await client.ohlcv(market: xbtusd, interval: .init(count: 1, unit: .day), from: start, through: end)
/// ```
///
/// A market's two assets are Kraken's own, asked of `/0/public/AssetPairs` and `/0/public/Assets` once per market
/// and kept for the client's life: each asset by Kraken's alternative name ("XBT", "USD") at Kraken's decimals.
///
/// A limit in Kraken's error list, or HTTP 429, throws ``KrakenLimitError``; any other error Kraken lists throws
/// ``KrakenAPIError``; number text that is not a number, or finer than an asset holds, throws ``AmountError``.
public struct KrakenOHLCVClient: OHLCVClient {
    public typealias MarketName = KrakenMarketName

    private let baseURL: URL
    private let session: any URLSessionProtocol
    private let now: @Sendable () -> Date
    private let markets: KrakenAssetPairBook

    /// - Parameters:
    ///   - baseURL: Kraken's REST root
    ///   - session: The session the requests go through; a test passes a recorded one
    ///   - now: The clock that says whether a bar has closed
    public init(
        baseURL: URL = URL(string: "https://api.kraken.com")!,
        session: any URLSessionProtocol = URLSession.session(config: DataFetch<URLSession>.urlSessionConfiguration()),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.now = now
        self.markets = KrakenAssetPairBook()
    }

    public func ohlcv(market: KrakenMarketName, interval: BarInterval, from: Date, through: Date) async throws -> [OHLCVClientBar] {
        let minutes = try Self.minutes(for: interval)
        // Kraken counts in whole seconds and answers the bars after `since`, so `since` is one second before the
        // range's first whole second; the range is never widened, the bars outside it are dropped below.
        let start = Int64((from.timeIntervalSince1970).rounded(.up))
        let end = Int64((through.timeIntervalSince1970).rounded(.down))
        guard start <= end else { return [] }

        let pair = try await self.pair(market)
        let rows = try await ohlc(market, minutes: minutes, since: start - 1)
        let clock = now().wireMilliseconds
        return try rows
            .filter { $0.openTime >= start && $0.openTime <= end }
            .map { try $0.bar(of: pair, intervalSeconds: Int64(minutes) * 60, now: clock) }
            .filter(\.isClosed)
    }

    public func openOHLCV(market: KrakenMarketName, interval: BarInterval) async throws -> OHLCVClientBar? {
        let minutes = try Self.minutes(for: interval)
        let pair = try await self.pair(market)
        let clock = now().wireMilliseconds
        let rows = try await ohlc(market, minutes: minutes, since: clock / 1000 - 2 * Int64(minutes) * 60)
        guard let bar = try rows.last.map({ try $0.bar(of: pair, intervalSeconds: Int64(minutes) * 60, now: clock) }), !bar.isClosed else {
            return nil
        }
        return bar
    }

    // Kraken's OHLC intervals in minutes: 1, 5, 15, 30, 60, 240, 1440, 10080, 21600.
    static func minutes(for interval: BarInterval) throws -> Int {
        let minutes: Int? = switch (interval.unit, interval.count) {
        case (.minute, let count) where [1, 5, 15, 30].contains(count): count
        case (.hour, 1): 60
        case (.hour, 4): 240
        case (.day, 1): 1_440
        case (.day, 15): 21_600
        case (.week, 1): 10_080
        default: nil
        }
        guard let minutes else {
            throw KrakenOHLCVError.unsupportedInterval(interval)
        }
        return minutes
    }

    private func pair(_ market: KrakenMarketName) async throws -> KrakenAssetPair {
        if let known = await markets.pair(market) {
            return known
        }
        let pairs: KrakenResult<[String: KrakenAssetPairInfo]> = try await get("/0/public/AssetPairs", [URLQueryItem(name: "pair", value: market.text)])
        guard let entry = pairs.result.first(where: { $0.key == market.text || $0.value.altname == market.text }) else {
            throw KrakenOHLCVError.unknownMarket(market)
        }
        let (key, info) = (entry.key, entry.value)
        let assets: KrakenResult<[String: KrakenAssetInfo]> = try await get("/0/public/Assets", [URLQueryItem(name: "asset", value: "\(info.base),\(info.quote)")])
        guard let base = assets.result[info.base], let quote = assets.result[info.quote] else {
            throw KrakenOHLCVError.unknownMarket(market)
        }
        let pair = KrakenAssetPair(
            key: key,
            base: try Asset(symbol: base.altname, unitExponent: base.decimals),
            quote: try Asset(symbol: quote.altname, unitExponent: quote.decimals)
        )
        await markets.keep(pair, as: market)
        return pair
    }

    private func ohlc(_ market: KrakenMarketName, minutes: Int, since: Int64) async throws -> [KrakenOHLCRow] {
        let answer: KrakenResult<KrakenOHLCResult> = try await get("/0/public/OHLC", [
            URLQueryItem(name: "pair", value: market.text),
            URLQueryItem(name: "interval", value: String(minutes)),
            URLQueryItem(name: "since", value: String(since))
        ])
        return answer.result.rows
    }

    private func get<Value: Decodable & Sendable>(_ path: String, _ query: [URLQueryItem]) async throws -> Value {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        guard let url = components.url else {
            throw DataFetchError.badURL("\(path) \(query)")
        }
        return try await ClientFetch.send(url, session: session, errorType: KrakenAPIError.self, errorForResponse: Self.limitError(for:body:))
    }

    // Kraken's limits as KrakenLimitError: HTTP 429, or a limit in its error list (which Kraken sends with HTTP 200);
    // nil for every other response, which the fetch reads.
    package static func limitError(for response: HTTPURLResponse, body: Data?) -> (any Error)? {
        let listed = WireResponse.decoded(body, as: KrakenAPIError.self)
        if response.statusCode == 429 || listed?.isLimit == true {
            return KrakenLimitError(retryAfter: WireResponse.retryAfter(response), apiError: listed)
        }
        return nil
    }
}

/// Why ``KrakenOHLCVClient`` could not hand up what was asked, where Kraken itself said nothing wrong
public enum KrakenOHLCVError: Error, Hashable, Sendable {
    /// Kraken has no OHLC interval of this length: 1, 5, 15 and 30 minutes; 1 and 4 hours; 1 and 15 days; 1 week
    case unsupportedInterval(BarInterval)
    /// A market's name that is not one Kraken could spell
    case malformedMarketName(String)
    /// Kraken's AssetPairs or Assets did not list the market or one of its assets
    case unknownMarket(KrakenMarketName)
}

// A Kraken pair with its two assets.
struct KrakenAssetPair: Sendable {
    let key: String
    let base: Asset
    let quote: Asset
}

private actor KrakenAssetPairBook {
    private var byName: [KrakenMarketName: KrakenAssetPair] = [:]

    func pair(_ market: KrakenMarketName) -> KrakenAssetPair? {
        byName[market]
    }

    func keep(_ pair: KrakenAssetPair, as market: KrakenMarketName) {
        byName[market] = pair
    }
}

// MARK: Response models

// Kraken's envelope: `{"error":[],"result":…}`. A body with errors and no result does not decode, so the fetch reads
// it as KrakenAPIError.
package struct KrakenResult<Result: Decodable & Sendable>: Decodable, Sendable {
    package let result: Result
}

// The part of an AssetPairs entry this client reads.
struct KrakenAssetPairInfo: Decodable, Sendable {
    let altname: String
    let base: String
    let quote: String
}

// The part of an Assets entry this client reads: the alternative name and the decimals Kraken keeps.
struct KrakenAssetInfo: Decodable, Sendable {
    let altname: String
    let decimals: Int
}

// `/0/public/OHLC`'s result: one array of rows under the pair's key, beside `last`.
struct KrakenOHLCResult: Decodable, Sendable {
    let rows: [KrakenOHLCRow]

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        guard let key = container.allKeys.first(where: { $0.stringValue != "last" }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "No pair's rows in Kraken's OHLC result"))
        }
        self.rows = try container.decode([KrakenOHLCRow].self, forKey: key)
    }
}

// One row as Kraken sends it, an array: [time, "open", "high", "low", "close", "vwap", "volume", count]
// The time is whole seconds; every number is text, decoded here into an exact WireDecimal. The vwap is not read.
struct KrakenOHLCRow: Decodable, Sendable {
    let openTime: Int64
    let open: WireDecimal
    let high: WireDecimal
    let low: WireDecimal
    let close: WireDecimal
    let volume: WireDecimal
    let trades: Int?

    init(from decoder: any Decoder) throws {
        var row = try decoder.unkeyedContainer()
        self.openTime = try row.decode(Int64.self)
        self.open = try WireDecimal(parsing: row.decode(String.self))
        self.high = try WireDecimal(parsing: row.decode(String.self))
        self.low = try WireDecimal(parsing: row.decode(String.self))
        self.close = try WireDecimal(parsing: row.decode(String.self))
        _ = try row.decode(String.self) // the vwap, not handed up
        self.volume = try WireDecimal(parsing: row.decode(String.self))
        self.trades = try row.decodeIfPresent(Int.self)
    }

    // The bar: Kraken states no close time, so it is the open plus the interval less one millisecond, as Binance's
    // and Hyperliquid's are; closed once the clock has passed it.
    func bar(of pair: KrakenAssetPair, intervalSeconds: Int64, now: Int64) throws -> OHLCVClientBar {
        let closeTime = (openTime + intervalSeconds) * 1000 - 1
        return OHLCVClientBar(
            openTime: Date(wireMilliseconds: openTime * 1000),
            closeTime: Date(wireMilliseconds: closeTime),
            open: try open.price(of: pair.quote, per: pair.base),
            high: try high.price(of: pair.quote, per: pair.base),
            low: try low.price(of: pair.quote, per: pair.base),
            close: try close.price(of: pair.quote, per: pair.base),
            volume: try volume.amount(of: pair.base),
            trades: trades,
            isClosed: now > closeTime
        )
    }
}
