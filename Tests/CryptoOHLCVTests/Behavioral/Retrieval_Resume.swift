// Retrieval_Resume.swift — § 5.1 and layer A: a second fetch starts from the kept history's last bar and adds only
// newer bars

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

@Suite("§ 5.1: the retrieval resumes from what it kept")
struct Retrieval_ResumeTests {
    let market = "BTCUSDT"

    /// Fetches bars 0…299, then asks again for 0…599 on a fresh feed; hands back the second report, the second feed
    /// and the store
    func twoFetches<S: OHLCVStore>(store: S, secondStore: S? = nil, missing: Set<Int> = [])
        async throws -> (OHLCVRetrievalReport, BehavioralBinanceFeed) {
        _ = try await Retrieve.make(Retrieve.minuteFeed(count: 600, missing: missing), store: store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: Retrieve.minute(0), through: Retrieve.minuteClose(299))
        let second = Retrieve.minuteFeed(count: 600, missing: missing)
        let report = try await Retrieve.make(second, store: secondStore ?? store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: Retrieve.minute(0), through: Retrieve.minuteClose(599))
        return (report, second)
    }

    @Test("§ 5.1: the second fetch's first request starts at the kept history's last bar, not at the range's start")
    func startsFromLastKept() async throws {
        let (_, feed) = try await twoFetches(store: BehavioralMemoryStore())
        let start = try #require(await feed.queries.first?["startTime"].flatMap { Int64($0) })
        let lastKept = ms(Retrieve.minute(299))
        #expect(start >= lastKept)
        #expect(start <= lastKept + Fx.minuteMs)
    }

    @Test("§ 5.1: the second fetch adds only bars newer than the kept history's last bar")
    func addsOnlyNewer() async throws {
        let (report, _) = try await twoFetches(store: BehavioralMemoryStore())
        #expect(report.added.count == 300)
        #expect(report.added.allSatisfy { $0.openTime > Retrieve.minute(299) })
    }

    @Test("§ 5.1: after the second fetch the store holds the whole range once, in order")
    func storeWholeOnce() async throws {
        let store = BehavioralMemoryStore()
        _ = try await twoFetches(store: store)
        let kept = try await store.bars(market: market, interval: Fx.minute)
        #expect(kept.map(\.openTime) == (0..<600).map { Retrieve.minute($0) })
    }

    @Test("§ 5.1: a second fetch with nothing newer adds nothing and leaves the store as it was")
    func nothingNewer() async throws {
        let store = BehavioralMemoryStore()
        let feed = Retrieve.minuteFeed(count: 300)
        _ = try await Retrieve.make(feed, store: store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: Retrieve.minute(0), through: Retrieve.minuteClose(299))
        let before = try await store.bars(market: market, interval: Fx.minute)
        let report = try await Retrieve.make(Retrieve.minuteFeed(count: 300), store: store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: Retrieve.minute(0), through: Retrieve.minuteClose(299))
        #expect(report.added.isEmpty)
        #expect(try await store.bars(market: market, interval: Fx.minute) == before)
    }

    @Test("§ 5.1: a gap between the kept history's last bar and the first newer bar is detected and kept")
    func gapAcrossResume() async throws {
        let store = BehavioralMemoryStore()
        let (report, _) = try await twoFetches(store: store, missing: [300, 301])
        let expected = OHLCVGap(after: Retrieve.minute(299), before: Retrieve.minute(302))
        #expect(report.gaps == [expected])
        #expect(try await store.gaps(market: market, interval: Fx.minute) == [expected])
    }

    @Test("§ 5.1 with OQ-S20: a file store reopened on the same directory resumes from what it kept")
    func fileStoreResumesAfterReopen() async throws {
        let directory = freshDirectory()
        let (report, feed) = try await twoFetches(store: try FileOHLCVStore(directory: directory),
                                                  secondStore: try FileOHLCVStore(directory: directory))
        #expect(report.added.count == 300)
        let start = try #require(await feed.queries.first?["startTime"].flatMap { Int64($0) })
        #expect(start >= ms(Retrieve.minute(299)))
        let reopened = try FileOHLCVStore(directory: directory)
        #expect(try await reopened.bars(market: market, interval: Fx.minute).count == 600)
    }
}
