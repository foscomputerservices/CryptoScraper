// D16_RangeUnrounded.swift — direction D16 with C32 and C8: the client and the retrieval take an absolute UTC range
// and a bar interval of count and unit, never a Duration, never a fosline timeframe; they round nothing

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

@Suite("D16: an interval of count and unit, a range not rounded")
struct D16_RangeUnroundedTests {
    /// 2024-01-01T00:07:13.500Z: on no bar boundary, with a fraction of a second
    let misalignedMs: Int64 = 1_704_067_633_500
    /// 2024-01-02T13:41:07.250Z
    let throughMs: Int64 = 1_704_202_867_250

    @Test("D16: the client's ohlcv takes the market, a BarInterval and two Dates, and nothing else")
    func ohlcvSignature() {
        let member: (BinanceOHLCVClient) -> (BinanceOHLCVClient.MarketName, BarInterval, Date, Date) async throws -> [OHLCVClientBar]
            = BinanceOHLCVClient.ohlcv(market:interval:from:through:)
        _ = member
    }

    @Test("D16: the client's openOHLCV takes the market and a BarInterval, and nothing else")
    func openOHLCVSignature() {
        let member: (BinanceOHLCVClient) -> (BinanceOHLCVClient.MarketName, BarInterval) async throws -> OHLCVClientBar?
            = BinanceOHLCVClient.openOHLCV(market:interval:)
        _ = member
    }

    @Test("D16: the retrieval's fetch takes the market, a BarInterval and two Dates")
    func retrievalSignature() {
        typealias Retrieval = OHLCVRetrieval<BinanceOHLCVClient, BehavioralMemoryStore>
        let member: (Retrieval) -> (BinanceOHLCVClient.MarketName, BarInterval, Date, Date) async throws -> OHLCVRetrievalReport
            = Retrieval.fetch(market:interval:from:through:)
        _ = member
    }

    @Test("D16 with C8: a bar interval encodes as its count and its unit, not as seconds and attoseconds")
    func intervalEncodesCountAndUnit() throws {
        let data = try JSONEncoder().encode(BarInterval(count: 15, unit: .minute))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["count", "unit"])
        #expect(object["count"] as? Int == 15)
    }

    // READING: C32 says bar alignment is the consumer's and the client has no calendar; the documents are silent on
    // a misaligned start. This test asserts the client neither rejects it nor moves it.
    @Test("D16 (READING): a start on no bar boundary is passed to the feed unchanged, to the millisecond, not rejected")
    func misalignedStartUnchanged() async throws {
        let session = RecordedSession(BinanceFixtures.dailyClosed)
        _ = try await Fx.binance(session).ohlcv(market: Fx.btcusdt, interval: Fx.day,
                                                from: date(ms: misalignedMs), through: date(ms: throughMs))
        let request = try #require(await session.requests.first)
        #expect(queryItems(of: request)["startTime"] == String(misalignedMs))
    }

    @Test("D16: the end of the range is passed to the feed unchanged, to the millisecond")
    func throughUnchanged() async throws {
        let session = RecordedSession(BinanceFixtures.dailyClosed)
        _ = try await Fx.binance(session).ohlcv(market: Fx.btcusdt, interval: Fx.day,
                                                from: date(ms: misalignedMs), through: date(ms: throughMs))
        let request = try #require(await session.requests.first)
        #expect(queryItems(of: request)["endTime"] == String(throughMs))
    }

    @Test("D16: the retrieval's first request on an empty store carries the range's start unchanged")
    func retrievalStartUnchanged() async throws {
        let feed = BehavioralBinanceFeed(firstOpenMs: Fx.jan1Ms, intervalMs: Fx.minuteMs, count: 100, nowMs: Fx.farFutureMs)
        _ = try await Retrieve.make(feed, store: BehavioralMemoryStore())
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: date(ms: misalignedMs), through: Retrieve.minuteClose(99))
        let first = try #require(await feed.queries.first)
        #expect(first["startTime"] == String(misalignedMs))
    }
}
