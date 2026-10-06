// HyperliquidOHLCVClientTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoExchange
import CryptoOHLCV
import FOSFoundation
import Foundation
import Testing

// § 8.6 and C32 for Hyperliquid's OHLCV client, against recorded responses.

@Suite("Hyperliquid OHLCV client")
struct HyperliquidOHLCVClientContractTests {
    static let btc = try! HyperliquidMarketName(validating: "BTC")
    // The 1d recording: 2025-10-01 through 2025-10-11 UTC.
    static let from = Date(timeIntervalSince1970: 1_759_276_800)
    static let through = Date(timeIntervalSince1970: 1_760_140_800)

    static func route(candles: String) -> @Sendable (URLRequest, Int) -> Reply {
        { request, _ in
            let type = request.jsonBody["type"] as? String
            return type == "meta" ? .ok(Feed.body("Hyperliquid/meta.json")) : .ok(Feed.body(candles))
        }
    }

    static func client(_ session: ReplaySession, now: Date = Feed.hyperliquidRecordedAt) -> HyperliquidOHLCVClient {
        HyperliquidOHLCVClient(session: session, now: { now })
    }

    @Test func everyNumberOfTheRecordedCandlesDecodesExactly() async throws {
        let session = ReplaySession(route: Self.route(candles: "Hyperliquid/candles-btc-1d.json"))
        let bars = try await Self.client(session).ohlcv(market: Self.btc, interval: Feed.day, from: Self.from, through: Self.through)
        let raw = Feed.json("Hyperliquid/candles-btc-1d.json") as! [[String: Any]]

        #expect(bars.count == raw.count)
        for (bar, candle) in zip(bars, raw) {
            #expect(bar.openTime.wireMilliseconds == (candle["t"] as! NSNumber).int64Value)
            #expect(bar.closeTime.wireMilliseconds == (candle["T"] as! NSNumber).int64Value)
            #expect([bar.open, bar.high, bar.low, bar.close].map(wireText) == ["o", "h", "l", "c"].map { normalized(candle[$0] as! String) })
            #expect(wireText(bar.volume) == normalized(candle["v"] as! String))
            #expect(bar.trades == (candle["n"] as! NSNumber).intValue)
            #expect(bar.isClosed)
        }
        #expect(bars.map(\.openTime) == bars.map(\.openTime).sorted())
    }

    @Test func thePricesAreInUSDCPerTheCoinAtItsSizeDecimals() async throws {
        let session = ReplaySession(route: Self.route(candles: "Hyperliquid/candles-btc-1d.json"))
        let first = try #require(try await Self.client(session).ohlcv(market: Self.btc, interval: Feed.day, from: Self.from, through: Self.through).first)
        #expect(first.open.quote == .usdc)
        #expect(first.open.base == (try Asset(symbol: "BTC", unitExponent: 5)))
        #expect(first.volume.asset.unitExponent == 5)
    }

    @Test func theRequestIsOneCandleSnapshotWithTheRangeInWholeMilliseconds() async throws {
        let session = ReplaySession(route: Self.route(candles: "Hyperliquid/candles-btc-1d.json"))
        _ = try await Self.client(session).ohlcv(market: Self.btc, interval: Feed.day, from: Self.from.addingTimeInterval(0.0004), through: Self.through)
        let snapshot = try #require(session.requests.last)
        let req = try #require(snapshot.jsonBody["req"] as? [String: Any])
        #expect(snapshot.httpMethod == "POST")
        #expect(snapshot.url?.path == "/info")
        #expect(snapshot.jsonBody["type"] as? String == "candleSnapshot")
        #expect(req["coin"] as? String == "BTC")
        #expect(req["interval"] as? String == "1d")
        #expect((req["startTime"] as? NSNumber)?.int64Value == 1_759_276_800_001)
        #expect((req["endTime"] as? NSNumber)?.int64Value == 1_760_140_800_000)
    }

    @Test func theCoinsSizeDecimalsAreAskedOnceForTheClientsLife() async throws {
        let session = ReplaySession(route: Self.route(candles: "Hyperliquid/candles-btc-1d.json"))
        let client = Self.client(session)
        _ = try await client.ohlcv(market: Self.btc, interval: Feed.day, from: Self.from, through: Self.through)
        _ = try await client.ohlcv(market: Self.btc, interval: Feed.day, from: Self.from, through: Self.through)
        #expect(session.requests.filter { $0.jsonBody["type"] as? String == "meta" }.count == 1)
    }

    @Test func openOHLCVHandsUpTheStillOpenCandleAndOHLCVNeverDoes() async throws {
        let session = ReplaySession(route: Self.route(candles: "Hyperliquid/candles-btc-4h-latest.json"))
        let client = Self.client(session)
        let open = try #require(try await client.openOHLCV(market: Self.btc, interval: Feed.fourHours))
        #expect(open.isClosed == false)
        #expect(open.openTime == Date(timeIntervalSince1970: 1_791_259_200))
        let closed = try await client.ohlcv(market: Self.btc, interval: Feed.fourHours,
                                           from: Date(timeIntervalSince1970: 1_791_244_800), through: Feed.hyperliquidRecordedAt)
        #expect(closed.map(\.openTime) == [Date(timeIntervalSince1970: 1_791_244_800)])
    }

    @Test func openOHLCVHandsUpNothingOnceTheLatestCandleHasClosed() async throws {
        let session = ReplaySession(route: Self.route(candles: "Hyperliquid/candles-btc-4h-latest.json"))
        #expect(try await Self.client(session, now: Date(timeIntervalSince1970: 1_791_273_600)).openOHLCV(market: Self.btc, interval: Feed.fourHours) == nil)
    }

    @Test func aCoinHyperliquidDoesNotListIsItsRefusalInItsOwnWords() async throws {
        let session = ReplaySession { request, _ in
            request.jsonBody["type"] as? String == "meta"
                ? .ok(Feed.body("Hyperliquid/meta.json"))
                : Reply(status: 500, body: Feed.body("Hyperliquid/error-unknown-coin.json"), headers: [:])
        }
        await #expect(throws: HyperliquidOHLCVError.refused(status: 500, text: "null")) {
            try await Self.client(session).ohlcv(market: Self.btc, interval: Feed.day, from: Self.from, through: Self.through)
        }
    }

    @Test func aCoinTheMetaDoesNotListIsAnUnknownMarket() async throws {
        let session = ReplaySession(route: Self.route(candles: "Hyperliquid/candles-btc-1d.json"))
        let nope = try HyperliquidMarketName(validating: "NOPE")
        await #expect(throws: HyperliquidOHLCVError.unknownMarket(nope)) {
            try await Self.client(session).ohlcv(market: nope, interval: Feed.day, from: Self.from, through: Self.through)
        }
    }

    @Test func a429IsTheTypedLimitWithRetryAfter() async throws {
        let session = ReplaySession { _, _ in Reply(status: 429, body: Data(), headers: ["Retry-After": "3"]) }
        await #expect(throws: HyperliquidLimitError(retryAfter: .seconds(3))) {
            try await Self.client(session).ohlcv(market: Self.btc, interval: Feed.day, from: Self.from, through: Self.through)
        }
    }

    @Test(arguments: [BarInterval(count: 2, unit: .minute), BarInterval(count: 6, unit: .hour), BarInterval(count: 2, unit: .week)])
    func anIntervalHyperliquidDoesNotOfferIsRefusedBeforeAnyRequest(interval: BarInterval) async throws {
        let session = ReplaySession(route: Self.route(candles: "Hyperliquid/candles-btc-1d.json"))
        await #expect(throws: HyperliquidOHLCVError.unsupportedInterval(interval)) {
            try await Self.client(session).ohlcv(market: Self.btc, interval: interval, from: Self.from, through: Self.through)
        }
        #expect(session.requests.isEmpty)
    }

    @Test func aMarketsNameKeepsItsCaseAndRefusesWhatHyperliquidCannotSpell() throws {
        #expect(try HyperliquidMarketName(validating: "kPEPE") != (try HyperliquidMarketName(validating: "KPEPE")))
        for bad in ["", "BTC USD", "BTC\"", String(repeating: "A", count: 33)] {
            #expect(throws: HyperliquidOHLCVError.malformedMarketName(bad)) { try HyperliquidMarketName(validating: bad) }
        }
        #expect(try HyperliquidMarketName(validating: "@107").toJSON().fromJSON() == (try HyperliquidMarketName(validating: "@107")))
    }
}
