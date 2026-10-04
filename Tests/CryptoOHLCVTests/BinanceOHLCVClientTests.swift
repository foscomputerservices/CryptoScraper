// BinanceOHLCVClientTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoOHLCV
import FOSFoundation
import Foundation
import Testing

// § 8.6 for the Binance client, against recorded responses: every number decoded exactly into Price and Amount,
// no String on the bar, the error path by errorType, the limit as a typed case, the open bar only from openOHLCV.

@Suite("Binance OHLCV client")
struct BinanceOHLCVClientTests {
    // MARK: Exact decode

    @Test func everyNumberOfAThousandKlinesDecodesExactly() async throws {
        let session = ReplaySession(route: binanceRoute)
        let bars = try await client(session).ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd)
        let raw = Recorded.rawRows(Recorded.page1)

        #expect(bars.count == 1000)
        #expect(raw.count == 1000)
        for (bar, row) in zip(bars, raw) {
            #expect(bar.openTime.milliseconds == row.openTime)
            let swiftTexts = [bar.open, bar.high, bar.low, bar.close].map(decimalText) + [decimalText(bar.volume)]
            #expect(swiftTexts == row.texts.map(strippedText), "kline \(row.openTime)")
        }
    }

    @Test func theFirstKlineIsTheExactValues() async throws {
        let session = ReplaySession(route: binanceRoute)
        let first = try #require(try await client(session).ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd).first)

        // [1502928000000,"4261.48000000","4485.39000000","4200.74000000","4285.08000000","795.15037700",1503014399999,…,3427,…]
        #expect(first.openTime == Date(milliseconds: 1_502_928_000_000))
        #expect(first.closeTime == Date(milliseconds: 1_503_014_399_999))
        #expect(first.open == Price(Amount(baseUnits: 426_148_000_000, asset: Binance.usdt), per: Binance.btc))
        #expect(first.high == Price(Amount(baseUnits: 448_539_000_000, asset: Binance.usdt), per: Binance.btc))
        #expect(first.low == Price(Amount(baseUnits: 420_074_000_000, asset: Binance.usdt), per: Binance.btc))
        #expect(first.close == Price(Amount(baseUnits: 428_508_000_000, asset: Binance.usdt), per: Binance.btc))
        #expect(first.volume == Amount(baseUnits: 79_515_037_700, asset: Binance.btc))
        #expect(first.trades == 3427)
        #expect(first.isClosed)
    }

    @Test func theMarketsAssetsComeFromExchangeInfoOnceWhenNotPassedIn() async throws {
        let session = ReplaySession(route: binanceRoute)
        let binance = client(session, markets: [])

        let market = try await binance.market(Binance.btcusdt)
        #expect(market.base == Binance.btc)
        #expect(market.quote == Binance.usdt)
        #expect(market.base.unitExponent == 8)
        #expect(market.quote.unitExponent == 8)

        let bars = try await binance.ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd)
        #expect(bars.first?.open.quote == Binance.usdt)
        #expect(session.requests.filter { $0.url!.path.hasSuffix("exchangeInfo") }.count == 1)
    }

    @Test func aPassedMarketIsNeverAskedOfBinance() async throws {
        let session = ReplaySession(route: binanceRoute)
        _ = try await client(session).ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd)
        #expect(session.requests.allSatisfy { $0.url!.path.hasSuffix("klines") })
    }

    @Test func theRequestCarriesTheRangeAsWholeMillisecondsAndThePageLimit() async throws {
        let session = ReplaySession(route: binanceRoute)
        _ = try await client(session).ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd)
        let request = try #require(session.requests.first)

        #expect(request.url!.host == "api.binance.com")
        #expect(request.url!.path == "/api/v3/klines")
        #expect(request.query("symbol") == "BTCUSDT")
        #expect(request.query("interval") == "1d")
        #expect(request.query("startTime") == "1502928000000")
        #expect(request.query("endTime") == "1606521600000")
        #expect(request.query("limit") == "1000")
    }

    @Test(arguments: [
        (BarInterval(count: 1, unit: .minute), "1m"), (BarInterval(count: 15, unit: .minute), "15m"),
        (BarInterval(count: 1, unit: .hour), "1h"), (BarInterval(count: 4, unit: .hour), "4h"),
        (BarInterval(count: 12, unit: .hour), "12h"), (BarInterval(count: 1, unit: .day), "1d"),
        (BarInterval(count: 3, unit: .day), "3d"), (BarInterval(count: 1, unit: .week), "1w")
    ])
    func eachIntervalIsBinancesToken(interval: BarInterval, token: String) async throws {
        let session = ReplaySession { _, _ in .emptyPage }
        _ = try await client(session).ohlcv(market: Binance.btcusdt, interval: interval, from: Recorded.rangeStart, through: Recorded.rangeEnd)
        #expect(session.requests.first?.query("interval") == token)
    }

    @Test(arguments: [BarInterval(count: 2, unit: .minute), BarInterval(count: 3, unit: .hour), BarInterval(count: 2, unit: .week)])
    func anIntervalBinanceDoesNotListIsRefusedBeforeAnyRequest(interval: BarInterval) async throws {
        let session = ReplaySession { _, _ in .emptyPage }
        await #expect(throws: BinanceOHLCVError.unsupportedInterval(interval)) {
            try await client(session).ohlcv(market: Binance.btcusdt, interval: interval, from: Recorded.rangeStart, through: Recorded.rangeEnd)
        }
        #expect(session.requests.isEmpty)
    }

    @Test func aReversedRangeAsksNothing() async throws {
        let session = ReplaySession(route: binanceRoute)
        let bars = try await client(session).ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeEnd, through: Recorded.rangeStart)
        #expect(bars.isEmpty)
        #expect(session.requests.isEmpty)
    }

    // MARK: No string reaches a value

    @Test func theBarHasNoStringProperty() async throws {
        let session = ReplaySession(route: binanceRoute)
        let bar = try #require(try await client(session).ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd).first)
        for child in Mirror(reflecting: bar).children {
            let type = type(of: child.value)
            #expect(type != String.self && type != String?.self && type != Substring.self, "\(child.label ?? "?") is text")
        }
        #expect(Mirror(reflecting: bar).children.count == 9)
    }

    // MARK: Malformed text, at the wire

    @Test(arguments: ["1e5", "+1", "1,000.00", " 1", "1..2", ".5", "5.", "", "-", "abc", "0x10", "١٢٣"])
    func textThatIsNotANumberIsMalformed(text: String) async throws {
        let body = Data(#"[[1502928000000,"\#(text)","1","1","1","1",1503014399999,"1",1,"1","1","0"]]"#.utf8)
        let session = ReplaySession { _, _ in .ok(body) }
        await #expect(throws: AmountError.malformedText(text)) {
            try await client(session).ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd)
        }
    }

    @Test func aVolumeFinerThanTheBaseUnitIsBelowBaseUnit() async throws {
        let body = Data(#"[[1502928000000,"1","1","1","1","0.000000001",1503014399999,"1",1,"1","1","0"]]"#.utf8)
        let session = ReplaySession { _, _ in .ok(body) }
        await #expect(throws: AmountError.belowBaseUnit("0.000000001", unitExponent: 8)) {
            try await client(session).ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd)
        }
    }

    @Test func aPriceBelowTheQuotesBaseUnitIsExactToNineDigitsMore() async throws {
        // 0.0000000123 USDT per BTC: two digits below USDT's base unit, held by the price's scale.
        let body = Data(#"[[1502928000000,"0.0000000123","1.100000000","1","1","1",1503014399999,"1",1,"1","1","0"]]"#.utf8)
        let session = ReplaySession { _, _ in .ok(body) }
        let bar = try #require(try await client(session).ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd).first)

        // × 100 BTC = 0.00000123 USDT = 123 base units, exactly
        #expect(bar.open.cost(of: Amount(whole: 100, of: Binance.btc)) == Amount(baseUnits: 123, asset: Binance.usdt))
        #expect(bar.high == Price(Amount(baseUnits: 110_000_000, asset: Binance.usdt), per: Binance.btc))
    }

    @Test func aPriceBeyondTheScaleIsBelowBaseUnit() async throws {
        let body = Data(#"[[1502928000000,"0.000000000000000001","1","1","1","1",1503014399999,"1",1,"1","1","0"]]"#.utf8)
        let session = ReplaySession { _, _ in .ok(body) }
        await #expect(throws: AmountError.belowBaseUnit("0.000000000000000001", unitExponent: 17)) {
            try await client(session).ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd)
        }
    }

    // MARK: The error path

    @Test func anErrorBodyDecodesByErrorTypeIntoBinancesError() async throws {
        let session = ReplaySession { _, _ in Reply(status: 400, body: Recorded.invalidSymbol, headers: [:]) }
        let nope = try BinanceMarketName(validating: "NOPEUSDT")
        let market = BinanceMarket(name: nope, base: Binance.btc, quote: Binance.usdt)
        await #expect(throws: BinanceAPIError(code: -1121, message: "Invalid symbol.")) {
            try await client(session, markets: [market]).ohlcv(market: nope, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd)
        }
    }

    @Test func anUnknownMarketInExchangeInfoIsBinancesError() async throws {
        let session = ReplaySession { _, _ in Reply(status: 400, body: Recorded.invalidSymbol, headers: [:]) }
        let nope = try BinanceMarketName(validating: "NOPEUSDT")
        await #expect(throws: BinanceAPIError(code: -1121, message: "Invalid symbol.")) {
            try await client(session, markets: []).market(nope)
        }
    }

    @Test(arguments: [429, 418])
    func aLimitResponseIsTheTypedLimitCaseWithRetryAfter(status: Int) async throws {
        let session = ReplaySession { _, _ in Reply(status: status, body: Recorded.limitBody, headers: ["Retry-After": "7"]) }
        do {
            _ = try await client(session).ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd)
            Issue.record("no error")
        } catch let limit as BinanceLimitError {
            #expect(limit.status == status)
            #expect(limit.retryAfter == .seconds(7))
            #expect(limit.apiError?.code == -1003)
            let readable: any OHLCVClientLimitError = limit
            #expect(readable.retryAfter == .seconds(7))
        }
    }

    @Test func aLimitResponseWithoutRetryAfterSaysNone() async throws {
        let session = ReplaySession { _, _ in Reply(status: 429, body: Recorded.limitBody, headers: [:]) }
        do {
            _ = try await client(session).ohlcv(market: Binance.btcusdt, interval: Binance.day, from: Recorded.rangeStart, through: Recorded.rangeEnd)
            Issue.record("no error")
        } catch let limit as BinanceLimitError {
            #expect(limit.status == 429)
            #expect(limit.retryAfter == nil)
        }
    }

    // MARK: The open bar

    @Test func openOHLCVHandsUpTheStillOpenBar() async throws {
        let session = ReplaySession(route: binanceRoute)
        let open = try #require(try await client(session).openOHLCV(market: Binance.btcusdt, interval: Binance.day))

        #expect(open.isClosed == false)
        #expect(open.openTime == Date(milliseconds: 1_791_072_000_000))
        #expect(open.open == Price(Amount(baseUnits: 8_475_357_000_000, asset: Binance.usdt), per: Binance.btc))
        #expect(session.requests.first?.query("limit") == "1")
        #expect(session.requests.first?.query("startTime") == nil)
    }

    @Test func openOHLCVHandsUpNothingOnceTheLatestBarHasClosed() async throws {
        let session = ReplaySession(route: binanceRoute)
        let afterClose = Date(milliseconds: 1_791_158_400_000)
        let open = try await client(session, now: afterClose).openOHLCV(market: Binance.btcusdt, interval: Binance.day)
        #expect(open == nil)
    }

    @Test func ohlcvNeverHandsUpTheOpenBar() async throws {
        let session = ReplaySession { _, _ in .ok(Recorded.latest) }
        let bars = try await client(session).ohlcv(
            market: Binance.btcusdt, interval: Binance.day,
            from: Date(milliseconds: 1_791_072_000_000), through: Recorded.recordedAt
        )
        #expect(bars.isEmpty)
    }

    // MARK: The market's name

    @Test func aMarketsNameIsValidatedAndUpperCased() throws {
        #expect(try BinanceMarketName(validating: "btcusdt").text == "BTCUSDT")
        for bad in ["", "BTC/USDT", "BTC USDT", "BTC-USDT", String(repeating: "A", count: 21), "ÄBC"] {
            #expect(throws: BinanceOHLCVError.malformedMarketName(bad)) { try BinanceMarketName(validating: bad) }
        }
    }

    @Test func aMarketsNameRoundTripsThroughJSON() throws {
        let name = try BinanceMarketName(validating: "ETHBTC")
        let back: BinanceMarketName = try name.toJSON().fromJSON()
        #expect(back == name)
        #expect(throws: (any Error).self) { let _: BinanceMarketName = try #""eth/btc""#.fromJSON() }
    }
}
