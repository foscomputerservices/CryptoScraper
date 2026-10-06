// CoinbaseOHLCVClientTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import CryptoOHLCV
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Testing

// § 8.6 and C32 for Coinbase's OHLCV client, against recorded responses.

@Suite("Coinbase OHLCV client")
struct CoinbaseOHLCVClientContractTests {
    static let btcusd = try! CoinbaseMarketName(validating: "BTC-USD")
    // The 1d recording: ten days, 2026-09-22 through 2026-10-01 UTC, newest first.
    static let from = Date(timeIntervalSince1970: 1_790_000_000)
    static let through = Date(timeIntervalSince1970: 1_790_864_000)

    static func route(candles: String) -> @Sendable (URLRequest, Int) -> Reply {
        { request, _ in
            request.url!.lastPathComponent == "candles" ? .ok(Feed.body(candles)) : .ok(Feed.body("Coinbase/product-btc-usd.json"))
        }
    }

    static func client(_ session: ReplaySession, now: Date = Feed.coinbaseRecordedAt) -> CoinbaseOHLCVClient {
        CoinbaseOHLCVClient(session: session, now: { now })
    }

    @Test func everyCandleDecodesExactlyOldestFirst() async throws {
        let session = ReplaySession(route: Self.route(candles: "Coinbase/candles-btc-usd-1d.json"))
        let bars = try await Self.client(session).ohlcv(market: Self.btcusd, interval: Feed.day, from: Self.from, through: Self.through)
        let raw = ((Feed.json("Coinbase/candles-btc-usd-1d.json") as! [String: Any])["candles"] as! [[String: String]]).reversed()

        #expect(bars.count == raw.count)
        for (bar, candle) in zip(bars, raw) {
            #expect(bar.openTime == Date(timeIntervalSince1970: TimeInterval(Int64(candle["start"]!)!)))
            #expect([bar.open, bar.high, bar.low, bar.close].map(wireText) == ["open", "high", "low", "close"].map { normalized(candle[$0]!) })
            #expect(wireText(bar.volume) == normalized(candle["volume"]!))
            #expect(bar.trades == nil)
            #expect(bar.isClosed)
        }
        #expect(bars.map(\.openTime) == bars.map(\.openTime).sorted())
    }

    @Test func theAssetsCarryTheDecimalsOfTheProductsIncrements() async throws {
        let session = ReplaySession(route: Self.route(candles: "Coinbase/candles-btc-usd-1d.json"))
        let first = try #require(try await Self.client(session).ohlcv(market: Self.btcusd, interval: Feed.day, from: Self.from, through: Self.through).first)
        #expect(first.open.base == .btc)
        #expect(first.open.quote == .usd)
    }

    @Test func theRequestCarriesTheRangeInWholeSecondsAndTheGranularity() async throws {
        let session = ReplaySession(route: Self.route(candles: "Coinbase/candles-btc-usd-1d.json"))
        _ = try await Self.client(session).ohlcv(market: Self.btcusd, interval: Feed.day, from: Self.from.addingTimeInterval(0.5), through: Self.through)
        let candles = try #require(session.requests.last)
        #expect(candles.url?.path == "/api/v3/brokerage/market/products/BTC-USD/candles")
        #expect(candles.query("start") == "1790000001")
        #expect(candles.query("end") == "1790864000")
        #expect(candles.query("granularity") == "ONE_DAY")
    }

    @Test func openOHLCVHandsUpTheStillOpenCandle() async throws {
        let session = ReplaySession(route: Self.route(candles: "Coinbase/candles-btc-usd-4h-latest.json"))
        let open = try #require(try await Self.client(session).openOHLCV(market: Self.btcusd, interval: Feed.fourHours))
        #expect(open.isClosed == false)
        #expect(open.openTime == Date(timeIntervalSince1970: 1_791_259_200))
    }

    @Test func anErrorBodyDecodesByErrorTypeIntoCoinbasesError() async throws {
        let session = ReplaySession { _, _ in Reply(status: 400, body: Feed.body("Coinbase/error-bad-granularity.json"), headers: [:]) }
        do {
            _ = try await Self.client(session).ohlcv(market: Self.btcusd, interval: Feed.day, from: Self.from, through: Self.through)
            Issue.record("no error")
        } catch let error as CoinbaseAPIError {
            #expect(error.code == "unknown")
            #expect(error.message.contains("TEN_MINUTE"))
        }
    }

    @Test func a429IsTheTypedLimitWithRetryAfter() async throws {
        let session = ReplaySession { _, _ in Reply(status: 429, body: Data(), headers: ["Retry-After": "1"]) }
        await #expect(throws: CoinbaseLimitError(retryAfter: .seconds(1), apiError: nil)) {
            try await Self.client(session).ohlcv(market: Self.btcusd, interval: Feed.day, from: Self.from, through: Self.through)
        }
    }

    @Test(arguments: [BarInterval(count: 3, unit: .minute), BarInterval(count: 12, unit: .hour), BarInterval(count: 1, unit: .week)])
    func anIntervalCoinbaseDoesNotOfferIsRefusedBeforeAnyRequest(interval: BarInterval) async throws {
        let session = ReplaySession(route: Self.route(candles: "Coinbase/candles-btc-usd-1d.json"))
        await #expect(throws: CoinbaseOHLCVError.unsupportedInterval(interval)) {
            try await Self.client(session).ohlcv(market: Self.btcusd, interval: interval, from: Self.from, through: Self.through)
        }
        #expect(session.requests.isEmpty)
    }

    @Test func aProductIdIsValidatedAndUpperCased() throws {
        #expect(try CoinbaseMarketName(validating: "btc-usd") == (try CoinbaseMarketName(validating: "BTC-USD")))
        for bad in ["", "BTC/USD", "BTC USD"] {
            #expect(throws: CoinbaseOHLCVError.malformedMarketName(bad)) { try CoinbaseMarketName(validating: bad) }
        }
    }
}
