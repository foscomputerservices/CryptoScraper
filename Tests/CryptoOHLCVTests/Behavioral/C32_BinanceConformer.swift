// C32_BinanceConformer.swift — C32, § 1 and § 8.6 against the Binance conformer: exact numbers, typed errors, the open bar

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

@Suite("C32: the Binance conformer")
struct C32_BinanceConformerTests {
    let jan1 = date(ms: Fx.jan1Ms)
    let jan3End = date(ms: Fx.jan1Ms + 3 * Fx.dayMs - 1)

    // MARK: Exact numbers (C32 with § 1, § 8.6)

    @Test("C32 with § 1: the recorded klines decode exactly into Price and Amount, every field")
    func recordedKlinesExact() async throws {
        let client = Fx.binance(RecordedSession(BinanceFixtures.dailyClosed))
        let bars = try await client.ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End)
        #expect(bars.count == 2)
        let first = try #require(bars.first)
        #expect(first.open == Fx.usdtPerBTC(baseUnits: 42_283_580_000))
        #expect(first.high == Fx.usdtPerBTC(baseUnits: 44_184_100_000))
        #expect(first.low == Fx.usdtPerBTC(baseUnits: 42_180_770_000))
        #expect(first.close == Fx.usdtPerBTC(baseUnits: 44_179_550_000))
        #expect(first.volume == Amount(baseUnits: 2_717_429_903_000, asset: Fx.btc))
        #expect(first.trades == 1_022_839)
        #expect(first.isClosed)
    }

    @Test("C32 with § 1: \"65000.00\" becomes exactly 65,000 USDT per BTC")
    func sixtyFiveThousandExact() async throws {
        let client = Fx.binance(RecordedSession(BinanceFixtures.exact))
        let bar = try #require(try await client.ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End).first)
        #expect(bar.open == Price(Amount(whole: 65_000, of: Fx.usdt), per: Fx.btc))
        #expect(bar.low == Fx.usdtPerBTC(baseUnits: 64_999_990_000))
        #expect(bar.close == Fx.usdtPerBTC(baseUnits: 65_000_100_000))
    }

    @Test("C32 with § 1: \"0.00012500\" becomes exactly 12,500 satoshis")
    func volumeExact() async throws {
        let client = Fx.binance(RecordedSession(BinanceFixtures.exact))
        let bar = try #require(try await client.ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End).first)
        #expect(bar.volume == Amount(baseUnits: 12_500, asset: Fx.btc))
        #expect(bar.trades == 7)
    }

    @Test("C32 with § 1: a price with more digits than the quote's base unit, \"65000.12345678\", is held exactly")
    func priceBelowQuoteBaseUnitExact() async throws {
        let client = Fx.binance(RecordedSession(BinanceFixtures.exact))
        let bar = try #require(try await client.ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End).first)
        // 65,000.12345678 USDT per BTC = 6,500,012,345,678 USDT base units per 100 BTC
        #expect(bar.high == Price(Amount(baseUnits: 6_500_012_345_678, asset: Fx.usdt), per: Amount(whole: 100, of: Fx.btc)))
    }

    @Test("C32 with § 1: a price below one quote base unit per whole base unit, \"0.00000123\", is held exactly")
    func subUnitPriceExact() async throws {
        let client = Fx.binance(RecordedSession(BinanceFixtures.subUnit))
        let bar = try #require(try await client.ohlcv(market: Fx.pepeusdt, interval: Fx.day, from: jan1, through: jan3End).first)
        // 0.00000123 USDT per PEPE = 123 USDT base units per 100 PEPE
        #expect(bar.open == Price(Amount(baseUnits: 123, asset: Fx.usdt), per: Amount(whole: 100, of: Fx.pepe)))
        #expect(bar.volume == Amount(baseUnits: 123_456_789, asset: Fx.pepe))
    }

    @Test("§ 8.6: no value the client hands up carries a String")
    func noStringHandedUp() async throws {
        let client = Fx.binance(RecordedSession(BinanceFixtures.dailyClosed))
        let bars = try await client.ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End)
        for bar in bars {
            #expect(Mirror(reflecting: bar).children.allSatisfy { !($0.value is String) && !($0.value is String?) })
        }
    }

    @Test("C32 with § 1: a malformed number throws AmountError.malformedText and hands up no value")
    func malformedThrows() async {
        let client = Fx.binance(RecordedSession(BinanceFixtures.malformed))
        let error = await caught { try await client.ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End) }
        guard case .malformedText = amountError(in: error) else {
            Issue.record("expected AmountError.malformedText, got \(String(describing: error))")
            return
        }
    }

    // READING: § 1 names AmountError.belowBaseUnit for text with more fraction digits than the base unit holds; the
    // documents are silent on whether a feed's volume of that kind throws or is rounded. This test asserts it throws,
    // since C3 says nothing rounds.
    @Test("C32 with § 1 (READING): a volume with more digits than the base unit throws AmountError.belowBaseUnit")
    func belowBaseUnitThrows() async {
        let client = Fx.binance(RecordedSession(BinanceFixtures.belowBaseUnit))
        let error = await caught { try await client.ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End) }
        guard case .belowBaseUnit = amountError(in: error) else {
            Issue.record("expected AmountError.belowBaseUnit, got \(String(describing: error))")
            return
        }
    }

    // MARK: Typed errors (§ 8.6)

    @Test("§ 8.6: Binance's error body decodes into the client's typed error with code -1121 and its message")
    func errorBodyTyped() async {
        let session = RecordedSession([RecordedResponse(status: 400, body: BinanceFixtures.invalidSymbol)])
        let client = Fx.binance(session)
        let error = await caught { try await client.ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End) }
        #expect(error != nil)
        #expect(error.flatMap(behavioralExchangeError) == BehavioralExchangeError(code: -1121, message: "Invalid symbol."))
    }

    // READING: § 8.6 says an error response decodes into the client's typed error; it is silent on how a 429 is
    // typed. This test asserts the typed error carries the Retry-After it was given, which the retrieval needs.
    @Test("§ 8.6 (READING): a 429 throws the client's typed limit error carrying its Retry-After")
    func limitTyped() async {
        let session = RecordedSession([RecordedResponse(status: 429, body: #"{"code":-1003,"msg":"Too much request weight used."}"#,
                                                        headers: ["Content-Type": "application/json", "Retry-After": "7"])])
        let client = Fx.binance(session)
        let error = await caught { try await client.ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End) }
        #expect(error != nil)
        #expect(error.flatMap(behavioralLimit) == BehavioralLimit(retryAfter: .seconds(7)))
    }

    // MARK: The request

    @Test("C32: the request names the market, the interval token and the range in milliseconds, on /api/v3/klines")
    func requestShape() async throws {
        let session = RecordedSession(BinanceFixtures.dailyClosed)
        _ = try await Fx.binance(session).ohlcv(market: Fx.btcusdt, interval: Fx.day, from: jan1, through: jan3End)
        let request = try #require(await session.requests.first)
        #expect(request.url?.path.hasSuffix("/api/v3/klines") == true)
        let query = queryItems(of: request)
        #expect(query["symbol"] == "BTCUSDT")
        #expect(query["interval"] == "1d")
        #expect(query["startTime"] == "1704067200000")
        #expect(query["endTime"] == "1704326399999")
    }

    @Test("C32 with C8: each bar interval is sent as Binance's token for it",
          arguments: zip([BarInterval(count: 1, unit: .minute), BarInterval(count: 15, unit: .minute),
                          BarInterval(count: 1, unit: .hour), BarInterval(count: 4, unit: .hour),
                          BarInterval(count: 12, unit: .hour), BarInterval(count: 1, unit: .day),
                          BarInterval(count: 1, unit: .week)],
                         ["1m", "15m", "1h", "4h", "12h", "1d", "1w"]))
    func intervalToken(interval: BarInterval, token: String) async throws {
        let session = RecordedSession(BinanceFixtures.empty)
        _ = try await Fx.binance(session).ohlcv(market: Fx.btcusdt, interval: interval, from: jan1, through: jan3End)
        let request = try #require(await session.requests.first)
        #expect(queryItems(of: request)["interval"] == token)
    }

    // MARK: The open bar

    @Test("C32: openOHLCV hands up the still-open bar with isClosed false")
    func openBarNotClosed() async throws {
        let client = Fx.binance(RecordedSession(BinanceFixtures.withOpen), nowMs: BinanceFixtures.withOpenNowMs)
        let open = try #require(try await client.openOHLCV(market: Fx.btcusdt, interval: Fx.day))
        #expect(open.isClosed == false)
        #expect(ms(open.openTime) == 1_704_240_000_000)
        #expect(open.open == Fx.usdtPerBTC(baseUnits: 44_946_910_000))
    }

    // READING: C32 declares openOHLCV optional and says "never a closed bar's stand-in"; the documents are silent on
    // when nil is handed up. This test asserts nil when the feed's answer holds no bar still open.
    @Test("C32 (READING): openOHLCV hands up nil, never a closed bar's stand-in, when the feed has no open bar")
    func openBarNilWhenNone() async throws {
        let client = Fx.binance(RecordedSession(BinanceFixtures.dailyClosed), nowMs: Fx.farFutureMs)
        let open = try await client.openOHLCV(market: Fx.btcusdt, interval: Fx.day)
        #expect(open == nil)
    }
}
