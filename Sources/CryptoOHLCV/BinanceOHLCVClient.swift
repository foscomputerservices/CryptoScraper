// BinanceOHLCVClient.swift
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

/// Binance spot's OHLCV client: closed klines from `/api/v3/klines`, every number decoded exactly
///
/// Each call is one request through FOSFoundation's fetch with ``BinanceAPIError`` as its error type, asking for at
/// most 1,000 klines whose open time falls in the range. The still-open kline is handed up only by
/// ``openOHLCV(market:interval:)``; ``ohlcv(market:interval:from:through:)`` hands up closed bars only.
///
/// ```swift
/// let client = BinanceOHLCVClient()
/// let market = try BinanceMarketName(validating: "BTCUSDT")
/// let days = try await client.ohlcv(market: market, interval: .init(count: 1, unit: .day), from: start, through: end)
/// let today = try await client.openOHLCV(market: market, interval: .init(count: 1, unit: .day))   // isClosed == false
/// ```
///
/// A market's two assets come from the markets passed in, or from `/api/v3/exchangeInfo`, asked once per market
/// and kept for the client's life; Binance's precision for each asset is its unit exponent.
///
/// A limit response, HTTP 429 or 418, throws ``BinanceLimitError`` with Binance's `Retry-After`; any other body
/// Binance states as an error throws ``BinanceAPIError``; number text that is not a number, or finer than an asset
/// holds, throws ``AmountError``.
public struct BinanceOHLCVClient: OHLCVClient {
    public typealias MarketName = BinanceMarketName

    /// Binance's largest page of klines
    public static let pageLimit = 1000

    private let baseURL: URL
    private let session: any URLSessionProtocol
    private let now: @Sendable () -> Date
    private let markets: MarketBook

    /// - Parameters:
    ///   - baseURL: Binance's REST root
    ///   - session: The session the requests go through; a test passes a recorded one
    ///   - markets: Markets whose assets the caller declares, so they are never asked of Binance
    ///   - now: The clock that says whether a kline has closed
    public init(
        baseURL: URL = URL(string: "https://api.binance.com")!,
        session: any URLSessionProtocol = URLSession.session(config: DataFetch<URLSession>.urlSessionConfiguration()),
        markets: [BinanceMarket] = [],
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.now = now
        self.markets = MarketBook(markets)
    }

    public func ohlcv(market: BinanceMarketName, interval: BarInterval, from: Date, through: Date) async throws -> [OHLCVClientBar] {
        let token = try Self.token(for: interval)
        // Whole milliseconds inside the range, so the range is never widened: up from `from`, down from `through`.
        let start = Int64((from.timeIntervalSince1970 * 1000).rounded(.up))
        let end = Int64((through.timeIntervalSince1970 * 1000).rounded(.down))
        guard start <= end else { return [] }

        let assets = try await self.market(market)
        let rows: [BinanceKlineRow] = try await get("/api/v3/klines", [
            URLQueryItem(name: "symbol", value: market.text),
            URLQueryItem(name: "interval", value: token),
            URLQueryItem(name: "startTime", value: String(start)),
            URLQueryItem(name: "endTime", value: String(end)),
            URLQueryItem(name: "limit", value: String(Self.pageLimit))
        ])
        let clock = now().milliseconds
        // Only the klines Binance was asked for: a row outside the range is never handed up.
        return try rows
            .filter { $0.openTime >= start && $0.openTime <= end }
            .map { try $0.bar(of: assets, now: clock) }
            .filter(\.isClosed)
    }

    public func openOHLCV(market: BinanceMarketName, interval: BarInterval) async throws -> OHLCVClientBar? {
        let token = try Self.token(for: interval)
        let assets = try await self.market(market)
        let rows: [BinanceKlineRow] = try await get("/api/v3/klines", [
            URLQueryItem(name: "symbol", value: market.text),
            URLQueryItem(name: "interval", value: token),
            URLQueryItem(name: "limit", value: "1")
        ])
        let clock = now().milliseconds
        guard let bar = try rows.last.map({ try $0.bar(of: assets, now: clock) }), !bar.isClosed else {
            return nil
        }
        return bar
    }

    /// The market's name and its two assets: the ones passed in, else Binance's, asked once
    ///
    /// - Throws: ``BinanceOHLCVError/unknownMarket(_:)`` when Binance does not list it
    public func market(_ name: BinanceMarketName) async throws -> BinanceMarket {
        if let known = await markets.market(name) {
            return known
        }
        let info: BinanceExchangeInfo = try await get("/api/v3/exchangeInfo", [
            URLQueryItem(name: "symbol", value: name.text)
        ])
        guard let symbol = info.symbols.first(where: { $0.symbol == name.text }) else {
            throw BinanceOHLCVError.unknownMarket(name)
        }
        let market = BinanceMarket(
            name: name,
            base: try Asset(symbol: symbol.baseAsset, unitExponent: symbol.baseAssetPrecision),
            quote: try Asset(symbol: symbol.quoteAsset, unitExponent: symbol.quoteAssetPrecision)
        )
        await markets.keep(market)
        return market
    }

    // Binance's kline interval tokens.
    static func token(for interval: BarInterval) throws -> String {
        let allowed: [Int] = switch interval.unit {
        case .minute: [1, 3, 5, 15, 30]
        case .hour: [1, 2, 4, 6, 8, 12]
        case .day: [1, 3]
        case .week: [1]
        }
        guard allowed.contains(interval.count) else {
            throw BinanceOHLCVError.unsupportedInterval(interval)
        }
        return interval.token
    }

    // One GET through FOSFoundation's fetch with Binance's error type. The fetch's hook sees every response before
    // the fetch reads it: a 429, or the 418 Binance sends once a caller kept asking after a 429, becomes
    // BinanceLimitError with Binance's Retry-After and its own body; every other response is the fetch's (AR69).
    private func get<Value: Decodable & Sendable>(_ path: String, _ query: [URLQueryItem]) async throws -> Value {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        guard let url = components.url else {
            throw DataFetchError.badURL("\(path) \(query)")
        }

        return try await Self.fetch(url, on: session)
    }

    // The session opened to its concrete type, which DataFetch is generic over.
    private static func fetch<Session: URLSessionProtocol, Value: Decodable & Sendable>(_ url: URL, on session: Session) async throws -> Value {
        try await DataFetch(urlSession: session, errorForResponse: limitError(for:body:))
            .fetch(url, errorType: BinanceAPIError.self)
    }

    // Binance's limit statuses as its typed error; nil for every other response. Binance sends Retry-After as whole
    // seconds; a limit body that is not Binance's error shape is carried as none.
    static func limitError(for response: HTTPURLResponse, body: Data?) -> (any Error)? {
        guard response.statusCode == 429 || response.statusCode == 418 else {
            return nil
        }
        let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
            .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .map { Duration.seconds($0) }
        return BinanceLimitError(status: response.statusCode, retryAfter: retryAfter, apiError: body.flatMap(Self.apiError(in:)))
    }

    private static func apiError(in body: Data) -> BinanceAPIError? {
        do {
            return try body.fromJSON()
        } catch {
            return nil // a limit response without Binance's body: the limit is still typed, with no body
        }
    }
}

// The markets a client knows, shared by every copy of the client.
private actor MarketBook {
    private var byName: [BinanceMarketName: BinanceMarket]

    init(_ markets: [BinanceMarket]) {
        self.byName = Dictionary(markets.map { ($0.name, $0) }, uniquingKeysWith: { _, last in last })
    }

    func market(_ name: BinanceMarketName) -> BinanceMarket? {
        byName[name]
    }

    func keep(_ market: BinanceMarket) {
        byName[market.name] = market
    }
}

// MARK: Response models

// One kline as Binance sends it, an array:
//   [openTime, "open", "high", "low", "close", "volume", closeTime, "quoteVolume", trades, "takerBase", "takerQuote", "0"]
// The times are integers of milliseconds; every number is text, decoded here into an exact WireDecimal. The fields
// past the trade count are not handed up and are not read.
struct BinanceKlineRow: Decodable, Sendable {
    let openTime: Int64
    let open: WireDecimal
    let high: WireDecimal
    let low: WireDecimal
    let close: WireDecimal
    let volume: WireDecimal
    let closeTime: Int64
    let trades: Int?

    init(from decoder: any Decoder) throws {
        var row = try decoder.unkeyedContainer()
        self.openTime = try row.decode(Int64.self)
        self.open = try WireDecimal(parsing: row.decode(String.self))
        self.high = try WireDecimal(parsing: row.decode(String.self))
        self.low = try WireDecimal(parsing: row.decode(String.self))
        self.close = try WireDecimal(parsing: row.decode(String.self))
        self.volume = try WireDecimal(parsing: row.decode(String.self))
        self.closeTime = try row.decode(Int64.self)
        _ = try row.decodeIfPresent(String.self) // the quote asset's volume, not handed up
        self.trades = try row.decodeIfPresent(Int.self)
    }

    // The bar, with the market's assets in hand; closed once the clock has passed Binance's close time, the bar's
    // last millisecond.
    func bar(of market: BinanceMarket, now: Int64) throws -> OHLCVClientBar {
        OHLCVClientBar(
            openTime: Date(milliseconds: openTime),
            closeTime: Date(milliseconds: closeTime),
            open: try open.price(of: market.quote, per: market.base),
            high: try high.price(of: market.quote, per: market.base),
            low: try low.price(of: market.quote, per: market.base),
            close: try close.price(of: market.quote, per: market.base),
            volume: try volume.amount(of: market.base),
            trades: trades,
            isClosed: now > closeTime
        )
    }
}

// The part of `/api/v3/exchangeInfo` this client reads: each market's two assets and their precision.
struct BinanceExchangeInfo: Decodable, Sendable {
    struct Symbol: Decodable, Sendable {
        let symbol: String
        let baseAsset: String
        let baseAssetPrecision: Int
        let quoteAsset: String
        let quoteAssetPrecision: Int
    }

    let symbols: [Symbol]
}
