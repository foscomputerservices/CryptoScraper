// HyperliquidOHLCVClient.swift
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

/// Hyperliquid's OHLCV client: closed candles of a perpetual from its info endpoint's `candleSnapshot`, every number
/// decoded exactly
///
/// Each call is one request through FOSFoundation's fetch, asking for the candles whose open time falls in the range
/// (Hyperliquid answers up to 5,000). The still-open candle is handed up only by ``openOHLCV(market:interval:)``;
/// ``ohlcv(market:interval:from:through:)`` hands up closed bars only.
///
/// ```swift
/// let client = HyperliquidOHLCVClient()
/// let btc = try HyperliquidMarketName(validating: "BTC")
/// let bars = try await client.ohlcv(market: btc, interval: .init(count: 4, unit: .hour), from: start, through: end)
/// ```
///
/// A market's base asset is the perpetual's coin at its size decimals, asked of the info endpoint's `meta` once and
/// kept for the client's life; its quote is USDC at six decimals, the exchange's unit of account (``Asset/usdc``).
///
/// A 429 throws ``HyperliquidLimitError``; any other refusal throws ``HyperliquidOHLCVError/refused(status:text:)``
/// with Hyperliquid's own text; number text that is not a number, or finer than an asset holds, throws
/// ``AmountError``.
public struct HyperliquidOHLCVClient: OHLCVClient {
    public typealias MarketName = HyperliquidMarketName

    private let baseURL: URL
    private let session: any URLSessionProtocol
    private let now: @Sendable () -> Date
    private let assets: HyperliquidAssetBook

    /// - Parameters:
    ///   - baseURL: Hyperliquid's REST root: production by default, `https://api.hyperliquid-testnet.xyz` for its test market
    ///   - session: The session the requests go through; a test passes a recorded one
    ///   - now: The clock that says whether a candle has closed
    public init(
        baseURL: URL = URL(string: "https://api.hyperliquid.xyz")!,
        session: any URLSessionProtocol = URLSession.session(config: DataFetch<URLSession>.urlSessionConfiguration()),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.now = now
        self.assets = HyperliquidAssetBook()
    }

    public func ohlcv(market: HyperliquidMarketName, interval: BarInterval, from: Date, through: Date) async throws -> [OHLCVClientBar] {
        let token = try Self.token(for: interval)
        // Whole milliseconds inside the range, so the range is never widened: up from `from`, down from `through`.
        let start = Int64((from.timeIntervalSince1970 * 1000).rounded(.up))
        let end = Int64((through.timeIntervalSince1970 * 1000).rounded(.down))
        guard start <= end else { return [] }

        let base = try await asset(of: market)
        let candles = try await candleSnapshot(market, token, start, end)
        let clock = now().wireMilliseconds
        return try candles
            .filter { $0.openTime >= start && $0.openTime <= end }
            .map { try $0.bar(base: base, now: clock) }
            .filter(\.isClosed)
    }

    public func openOHLCV(market: HyperliquidMarketName, interval: BarInterval) async throws -> OHLCVClientBar? {
        let token = try Self.token(for: interval)
        let base = try await asset(of: market)
        let clock = now().wireMilliseconds
        let candles = try await candleSnapshot(market, token, clock - 2 * interval.milliseconds, clock)
        guard let bar = try candles.last.map({ try $0.bar(base: base, now: clock) }), !bar.isClosed else {
            return nil
        }
        return bar
    }

    // Hyperliquid's candle intervals: 1m 3m 5m 15m 30m, 1h 2h 4h 8h 12h, 1d 3d, 1w (its month is no BarInterval).
    static func token(for interval: BarInterval) throws -> String {
        let allowed: [Int] = switch interval.unit {
        case .minute: [1, 3, 5, 15, 30]
        case .hour: [1, 2, 4, 8, 12]
        case .day: [1, 3]
        case .week: [1]
        }
        guard allowed.contains(interval.count) else {
            throw HyperliquidOHLCVError.unsupportedInterval(interval)
        }
        return interval.token
    }

    private func asset(of market: HyperliquidMarketName) async throws -> Asset {
        if let known = await assets.asset(market) {
            return known
        }
        let meta: HyperliquidPerpMeta = try await info(Data(#"{"type":"meta"}"#.utf8))
        await assets.keep(meta)
        guard let asset = await assets.asset(market) else {
            throw HyperliquidOHLCVError.unknownMarket(market)
        }
        return asset
    }

    private func candleSnapshot(_ market: HyperliquidMarketName, _ token: String, _ start: Int64, _ end: Int64) async throws -> [HyperliquidCandle] {
        // The coin's name is the one field written from text; it was validated to carry no character JSON escapes.
        let body = #"{"type":"candleSnapshot","req":{"coin":"\#(market.text)","interval":"\#(token)","startTime":\#(start),"endTime":\#(end)}}"#
        let candles: [HyperliquidCandle]? = try await info(Data(body.utf8))
        // Hyperliquid answers a coin it does not list with HTTP 500 and the body `null`, so a refusal of the
        // market is only ever the hook's; a 200 `null` is no candles.
        return candles ?? []
    }

    private func info<Value: Decodable & Sendable>(_ body: Data) async throws -> Value {
        try await ClientFetch.send(
            baseURL.appendingPathComponent("info"),
            method: "POST",
            body: body,
            session: session,
            errorForResponse: Self.refusal(for:body:)
        )
    }

    // Hyperliquid's refusals as typed errors; nil for a 2xx, which the fetch reads.
    static func refusal(for response: HTTPURLResponse, body: Data?) -> (any Error)? {
        switch response.statusCode {
        case 200..<300:
            return nil
        case 429:
            return HyperliquidLimitError(retryAfter: WireResponse.retryAfter(response))
        default:
            return HyperliquidOHLCVError.refused(status: response.statusCode, text: body.map { String(decoding: $0, as: UTF8.self) } ?? "")
        }
    }
}

/// Why ``HyperliquidOHLCVClient`` could not hand up what was asked
///
/// ```swift
/// catch HyperliquidOHLCVError.refused(let status, let text) { … }      // Hyperliquid's own words
/// ```
public enum HyperliquidOHLCVError: Error, Hashable, Sendable {
    /// Hyperliquid has no candle interval of this length
    case unsupportedInterval(BarInterval)
    /// A market's name that is not one Hyperliquid could spell
    case malformedMarketName(String)
    /// Hyperliquid's `meta` does not list the market
    case unknownMarket(HyperliquidMarketName)
    /// Hyperliquid refused the request, with its HTTP status and its body as it wrote it (a coin it does not list
    /// is HTTP 500 with the body `null`)
    case refused(status: Int, text: String)
}

// The perpetuals' size decimals, shared by every copy of the client.
private actor HyperliquidAssetBook {
    private var byName: [String: Int] = [:]

    func asset(_ market: HyperliquidMarketName) -> Asset? {
        guard let exponent = byName[market.text] else { return nil }
        do {
            return try Asset(symbol: market.text, unitExponent: exponent)
        } catch {
            return nil // a coin whose name is no asset symbol ("@107") is a market this client cannot price
        }
    }

    func keep(_ meta: HyperliquidPerpMeta) {
        for coin in meta.universe {
            byName[coin.name] = coin.szDecimals
        }
    }
}

// MARK: Response models

// The part of `meta` this client reads: each perpetual's name and size decimals.
struct HyperliquidPerpMeta: Decodable, Sendable {
    struct Coin: Decodable, Sendable {
        let name: String
        let szDecimals: Int
    }

    let universe: [Coin]
}

// One candle as Hyperliquid sends it:
//   {"t":<open ms>,"T":<close ms, the candle's last millisecond>,"s":"BTC","i":"4h","o":"…","c":"…","h":"…","l":"…","v":"…","n":<trades>}
// Every number is text, decoded here into an exact WireDecimal.
struct HyperliquidCandle: Decodable, Sendable {
    let openTime: Int64
    let closeTime: Int64
    let open: WireDecimal
    let high: WireDecimal
    let low: WireDecimal
    let close: WireDecimal
    let volume: WireDecimal
    let trades: Int?

    private enum CodingKeys: String, CodingKey {
        case openTime = "t", closeTime = "T", open = "o", high = "h", low = "l", close = "c", volume = "v", trades = "n"
    }

    // The bar, with the coin's asset in hand; closed once the clock has passed Hyperliquid's close time.
    func bar(base: Asset, now: Int64) throws -> OHLCVClientBar {
        OHLCVClientBar(
            openTime: Date(wireMilliseconds: openTime),
            closeTime: Date(wireMilliseconds: closeTime),
            open: try open.price(of: .usdc, per: base),
            high: try high.price(of: .usdc, per: base),
            low: try low.price(of: .usdc, per: base),
            close: try close.price(of: .usdc, per: base),
            volume: try volume.amount(of: base),
            trades: trades,
            isClosed: now > closeTime
        )
    }
}
