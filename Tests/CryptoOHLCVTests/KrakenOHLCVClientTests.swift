// KrakenOHLCVClientTests.swift
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

// § 8.6 and C32 for Kraken's OHLCV client, against recorded responses.

@Suite("Kraken OHLCV client")
struct KrakenOHLCVClientContractTests {
    static let xbtusd = try! KrakenMarketName(validating: "XBTUSD")
    // The 1d recording: 38 rows from 2026-08-30, the last the open day of 2026-10-06.
    static let from = Date(timeIntervalSince1970: 1_788_048_000)
    static let through = Feed.krakenRecordedAt

    static let route: @Sendable (URLRequest, Int) -> Reply = { request, _ in
        switch request.url!.lastPathComponent {
        case "AssetPairs": .ok(Feed.body("Kraken/asset-pairs-xbtusd.json"))
        case "Assets": .ok(Feed.body("Kraken/assets-xbt-zusd.json"))
        default: .ok(Feed.body("Kraken/ohlc-xbtusd-1d.json"))
        }
    }

    static func client(_ session: ReplaySession, now: Date = Feed.krakenRecordedAt) -> KrakenOHLCVClient {
        KrakenOHLCVClient(session: session, now: { now })
    }

    static var rawRows: [[Any]] {
        let result = (Feed.json("Kraken/ohlc-xbtusd-1d.json") as! [String: Any])["result"] as! [String: Any]
        return result["XXBTZUSD"] as! [[Any]]
    }

    @Test func everyClosedRowDecodesExactlyAndTheOpenOneIsLeftOut() async throws {
        let session = ReplaySession(route: Self.route)
        let bars = try await Self.client(session).ohlcv(market: Self.xbtusd, interval: Feed.day, from: Self.from, through: Self.through)
        let raw = Self.rawRows

        #expect(bars.count == raw.count - 1)
        for (bar, row) in zip(bars, raw) {
            #expect(bar.openTime == Date(timeIntervalSince1970: TimeInterval((row[0] as! NSNumber).int64Value)))
            #expect([bar.open, bar.high, bar.low, bar.close].map(wireText) == (1...4).map { normalized(row[$0] as! String) })
            #expect(wireText(bar.volume) == normalized(row[6] as! String))
            #expect(bar.trades == (row[7] as! NSNumber).intValue)
            #expect(bar.closeTime.wireMilliseconds == bar.openTime.wireMilliseconds + 86_400_000 - 1)
            #expect(bar.isClosed)
        }
    }

    // Carried in step 4a of the identity PR: the market's assets are Kraken's declared holdings, no longer assets made
    // from Kraken's symbol and decimals; Kraken's decimals are the declared holdings'.
    @Test func theAssetsAreKrakensOwnAtKrakensDecimals() async throws {
        let session = ReplaySession(route: Self.route)
        let first = try #require(try await Self.client(session).ohlcv(market: Self.xbtusd, interval: Feed.day, from: Self.from, through: Self.through).first)
        #expect(first.open.base.id == EXCHANGE.Kraken.chainId + ":XBT")
        #expect(first.open.quote.id == EXCHANGE.Kraken.chainId + ":USD")
        #expect(try AssetRegistry.shared.decimals(of: first.open.base) == 10)
        #expect(try AssetRegistry.shared.decimals(of: first.open.quote) == 4)
    }

    @Test func theRequestCarriesThePairTheMinutesAndTheSecondBeforeTheRange() async throws {
        let session = ReplaySession(route: Self.route)
        _ = try await Self.client(session).ohlcv(market: Self.xbtusd, interval: Feed.day, from: Self.from, through: Self.through)
        let ohlc = try #require(session.requests.last)
        #expect(ohlc.url?.path == "/0/public/OHLC")
        #expect(ohlc.query("pair") == "XBTUSD")
        #expect(ohlc.query("interval") == "1440")
        #expect(ohlc.query("since") == "1788047999")
    }

    @Test func openOHLCVHandsUpTheStillOpenDay() async throws {
        let session = ReplaySession(route: Self.route)
        let open = try #require(try await Self.client(session).openOHLCV(market: Self.xbtusd, interval: Feed.day))
        #expect(open.isClosed == false)
        #expect(open.openTime == Date(timeIntervalSince1970: 1_791_244_800))
    }

    @Test func anErrorKrakenListsIsItsTypedError() async throws {
        let session = ReplaySession { _, _ in .ok(Feed.body("Kraken/error-unknown-pair.json")) }
        await #expect(throws: KrakenAPIError(messages: ["EQuery:Unknown asset pair"])) {
            try await Self.client(session).ohlcv(market: Self.xbtusd, interval: Feed.day, from: Self.from, through: Self.through)
        }
    }

    @Test func aLimitInKrakensListIsTheTypedLimit() async throws {
        let session = ReplaySession { _, _ in .ok(Data(#"{"error":["EAPI:Rate limit exceeded"]}"#.utf8)) }
        await #expect(throws: KrakenLimitError(retryAfter: nil, apiError: KrakenAPIError(messages: ["EAPI:Rate limit exceeded"]))) {
            try await Self.client(session).ohlcv(market: Self.xbtusd, interval: Feed.day, from: Self.from, through: Self.through)
        }
    }

    @Test func a429IsTheTypedLimitWithRetryAfter() async throws {
        let session = ReplaySession { _, _ in Reply(status: 429, body: Data(), headers: ["Retry-After": "2"]) }
        await #expect(throws: KrakenLimitError(retryAfter: .seconds(2), apiError: nil)) {
            try await Self.client(session).ohlcv(market: Self.xbtusd, interval: Feed.day, from: Self.from, through: Self.through)
        }
    }

    @Test(arguments: [BarInterval(count: 3, unit: .minute), BarInterval(count: 2, unit: .hour), BarInterval(count: 3, unit: .day)])
    func anIntervalKrakenDoesNotOfferIsRefusedBeforeAnyRequest(interval: BarInterval) async throws {
        let session = ReplaySession(route: Self.route)
        await #expect(throws: KrakenOHLCVError.unsupportedInterval(interval)) {
            try await Self.client(session).ohlcv(market: Self.xbtusd, interval: interval, from: Self.from, through: Self.through)
        }
        #expect(session.requests.isEmpty)
    }
}
