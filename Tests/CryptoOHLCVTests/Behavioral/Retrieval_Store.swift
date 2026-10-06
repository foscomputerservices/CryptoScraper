// Retrieval_Store.swift — § 5.1, OQ-S20 and D17: the store protocol's contract, run against every conformer (the
// test's memory store and the shipped file store); the file store survives a reopen; the showcase needs no database

import Testing
import Foundation
import CryptoAsset
import CryptoOHLCV
import CryptoReference

/// A closed minute bar at `index`, every value distinct and exact, a sub-unit high among them
func storeBar(_ index: Int, trades: Int? = 10) -> OHLCVClientBar {
    OHLCVClientBar.stub(openTime: Retrieve.minute(index), closeTime: Retrieve.minuteClose(index),
                        open: Fx.usdtPerBTC(baseUnits: Int128(1000 + index) * 1_000_000),
                        // a price below one USDT base unit per BTC beyond the whole: 1000+i.0000005 USDT
                        high: Price(Amount(baseUnits: (Int128(1000 + index) * 1_000_000 + 1) * 2 - 1, asset: Fx.usdt),
                                    per: Amount(whole: 2, of: Fx.btc)),
                        low: Fx.usdtPerBTC(baseUnits: Int128(999 + index) * 1_000_000),
                        close: syntheticClose(index: index),
                        volume: Amount(baseUnits: 12_500, asset: Fx.btc),
                        trades: trades, isClosed: true)
}

/// Two bars are the same bar: every value equal, the times to the millisecond
func sameBar(_ a: OHLCVClientBar, _ b: OHLCVClientBar) -> Bool {
    ms(a.openTime) == ms(b.openTime) && ms(a.closeTime) == ms(b.closeTime)
        && a.open == b.open && a.high == b.high && a.low == b.low && a.close == b.close
        && a.volume == b.volume && a.trades == b.trades && a.isClosed == b.isClosed
}

func sameBars(_ a: [OHLCVClientBar], _ b: [OHLCVClientBar]) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy(sameBar)
}

@Suite("§ 5.1 with OQ-S20: the store protocol's contract, on every conformer")
struct Retrieval_StoreContractTests {
    @Test("OQ-S20: an empty store reads back no bars and no gaps", arguments: StoreKind.allCases)
    func emptyStore(kind: StoreKind) async throws {
        let store = try kind.make()
        #expect(try await store.bars(market: "BTCUSDT", interval: Fx.minute).isEmpty)
        #expect(try await store.gaps(market: "BTCUSDT", interval: Fx.minute).isEmpty)
    }

    @Test("§ 5.1: what is kept reads back in order, value for value", arguments: StoreKind.allCases)
    func keptReadsBack(kind: StoreKind) async throws {
        let store = try kind.make()
        let bars = (0..<50).map { storeBar($0) }
        try await store.keep(bars, market: "BTCUSDT", interval: Fx.minute)
        #expect(sameBars(try await store.bars(market: "BTCUSDT", interval: Fx.minute), bars))
    }

    @Test("§ 5.1: a second keep adds to the first", arguments: StoreKind.allCases)
    func keepAdds(kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.keep((0..<10).map { storeBar($0) }, market: "BTCUSDT", interval: Fx.minute)
        try await store.keep((10..<20).map { storeBar($0) }, market: "BTCUSDT", interval: Fx.minute)
        #expect(sameBars(try await store.bars(market: "BTCUSDT", interval: Fx.minute), (0..<20).map { storeBar($0) }))
    }

    @Test("§ 1 with OQ-S20: exact prices, a sub-unit price, a nil trade count and millisecond times survive the store",
          arguments: StoreKind.allCases)
    func exactValuesSurvive(kind: StoreKind) async throws {
        let store = try kind.make()
        let bars = [storeBar(0, trades: nil), storeBar(1)]
        try await store.keep(bars, market: "BTCUSDT", interval: Fx.minute)
        let read = try await store.bars(market: "BTCUSDT", interval: Fx.minute)
        #expect(sameBars(read, bars))
        #expect(read.first?.trades == nil)
        #expect(read.first.map { ms($0.closeTime) } == Fx.jan1Ms + Fx.minuteMs - 1)
    }

    // READING: the brief says what is kept is "readable back … in order"; the documents are silent on whether the
    // store or its caller orders it. This test asserts the store reads back in open-time order whatever the keep order.
    @Test("§ 5.1 (READING): bars kept out of order read back in open-time order", .disabled("Classified 2026-10-04: the file-store argument fails and the memory-store argument passes: the documents are silent on whether the store or its caller orders and dedupes, and the shipped file store keeps what it is handed, append-only, in the order handed; see validation/step2-ledgers/layer-a-builder.md"), arguments: StoreKind.allCases)
    func ordersOnRead(kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.keep([storeBar(2), storeBar(0)], market: "BTCUSDT", interval: Fx.minute)
        try await store.keep([storeBar(1)], market: "BTCUSDT", interval: Fx.minute)
        #expect(try await store.bars(market: "BTCUSDT", interval: Fx.minute).map(\.openTime)
                == [Retrieve.minute(0), Retrieve.minute(1), Retrieve.minute(2)])
    }

    // READING: "nothing dropped or doubled" is said of the retrieval; the documents are silent on whether the store
    // itself refuses a double. This test asserts a bar kept twice at one open time reads back once.
    @Test("§ 5.1 (READING): a bar kept twice at one open time reads back once", .disabled("Classified 2026-10-04: the file-store argument fails and the memory-store argument passes: the documents are silent on whether the store or its caller orders and dedupes, and the shipped file store keeps what it is handed, append-only, in the order handed; see validation/step2-ledgers/layer-a-builder.md"), arguments: StoreKind.allCases)
    func noDoubleOnKeep(kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.keep([storeBar(0), storeBar(1)], market: "BTCUSDT", interval: Fx.minute)
        try await store.keep([storeBar(1), storeBar(2)], market: "BTCUSDT", interval: Fx.minute)
        #expect(try await store.bars(market: "BTCUSDT", interval: Fx.minute).count == 3)
    }

    @Test("§ 5.1: each market and interval is its own series", arguments: StoreKind.allCases)
    func seriesSeparate(kind: StoreKind) async throws {
        let store = try kind.make()
        try await store.keep((0..<3).map { storeBar($0) }, market: "BTCUSDT", interval: Fx.minute)
        try await store.keep([storeBar(5)], market: "ETHUSDT", interval: Fx.minute)
        try await store.keep([storeBar(7)], market: "BTCUSDT", interval: Fx.day)
        #expect(try await store.bars(market: "BTCUSDT", interval: Fx.minute).count == 3)
        #expect(try await store.bars(market: "ETHUSDT", interval: Fx.minute).map(\.openTime) == [Retrieve.minute(5)])
        #expect(try await store.bars(market: "BTCUSDT", interval: Fx.day).map(\.openTime) == [Retrieve.minute(7)])
    }

    @Test("§ 5.1: a kept gap reads back as the gap it was", arguments: StoreKind.allCases)
    func gapsReadBack(kind: StoreKind) async throws {
        let store = try kind.make()
        let gaps = [OHLCVGap(after: Retrieve.minute(9), before: Retrieve.minute(12)),
                    OHLCVGap(after: Retrieve.minute(40), before: Retrieve.minute(42))]
        try await store.keep(gaps, market: "BTCUSDT", interval: Fx.minute)
        let read = try await store.gaps(market: "BTCUSDT", interval: Fx.minute)
        #expect(read.map { [ms($0.after), ms($0.before)] } == gaps.map { [ms($0.after), ms($0.before)] })
    }

    @Test("§ 5.1 with OQ-S20: the retrieval keeps through either conformer alike", arguments: StoreKind.allCases)
    func retrievalOnEither(kind: StoreKind) async throws {
        let feed = Retrieve.minuteFeed(count: 1_200, missing: [600])
        let report: OHLCVRetrievalReport
        let read: [OHLCVClientBar]
        switch kind {
        case .memory:
            let store = BehavioralMemoryStore()
            report = try await Retrieve.make(feed, store: store)
                .fetch(market: Fx.btcusdt, interval: Fx.minute, from: Retrieve.minute(0), through: Retrieve.minuteClose(1_199))
            read = try await store.bars(market: "BTCUSDT", interval: Fx.minute)
        case .file:
            let store = try FileOHLCVStore(directory: freshDirectory())
            report = try await Retrieve.make(feed, store: store)
                .fetch(market: Fx.btcusdt, interval: Fx.minute, from: Retrieve.minute(0), through: Retrieve.minuteClose(1_199))
            read = try await store.bars(market: "BTCUSDT", interval: Fx.minute)
        }
        #expect(read.count == 1_199)
        #expect(report.gaps == [OHLCVGap(after: Retrieve.minute(599), before: Retrieve.minute(601))])
    }
}

@Suite("OQ-S20: the shipped file store")
struct Retrieval_FileStoreTests {
    @Test("OQ-S20: the file store is a conformer of the store protocol")
    func conforms() throws {
        func requireStore<S: OHLCVStore>(_ store: S) -> S { store }
        _ = requireStore(try FileOHLCVStore(directory: freshDirectory()))
    }

    @Test("OQ-S20: a file store closed and reopened on the same directory reads back its bars and gaps")
    func survivesReopen() async throws {
        let directory = freshDirectory()
        let bars = (0..<30).map { storeBar($0) }
        let gap = OHLCVGap(after: Retrieve.minute(29), before: Retrieve.minute(31))
        do {
            let store = try FileOHLCVStore(directory: directory)
            try await store.keep(bars, market: "BTCUSDT", interval: Fx.minute)
            try await store.keep([gap], market: "BTCUSDT", interval: Fx.minute)
        }
        let reopened = try FileOHLCVStore(directory: directory)
        #expect(sameBars(try await reopened.bars(market: "BTCUSDT", interval: Fx.minute), bars))
        #expect(try await reopened.gaps(market: "BTCUSDT", interval: Fx.minute).map { ms($0.after) } == [ms(gap.after)])
    }

    @Test("OQ-S20: two file stores on two directories are two stores")
    func directoriesIndependent() async throws {
        let first = try FileOHLCVStore(directory: freshDirectory())
        let second = try FileOHLCVStore(directory: freshDirectory())
        try await first.keep([storeBar(0)], market: "BTCUSDT", interval: Fx.minute)
        #expect(try await second.bars(market: "BTCUSDT", interval: Fx.minute).isEmpty)
    }
}

@Suite("D17: the showcase runs alone")
struct D17_ShowcaseTests {
    @Test("D17 with OQ-S20: the retrieval fetches and keeps a history with the file store alone, no database")
    func fileStoreAlone() async throws {
        let directory = freshDirectory()
        let store = try FileOHLCVStore(directory: directory)
        let report = try await Retrieve.make(Retrieve.minuteFeed(count: 1_500), store: store)
            .fetch(market: Fx.btcusdt, interval: Fx.minute, from: Retrieve.minute(0), through: Retrieve.minuteClose(1_499))
        #expect(report.added.count == 1_500)
        #expect(try await FileOHLCVStore(directory: directory).bars(market: "BTCUSDT", interval: Fx.minute).count == 1_500)
    }

    // READING: OQ-S20 says the library ships a file conformer; the documents are silent on where it writes. This test
    // asserts it writes only inside the directory it is given, so the showcase leaves nothing elsewhere.
    @Test("D17 (READING): the file store writes only inside the directory it was given")
    func writesInsideItsDirectory() async throws {
        let parent = freshDirectory()
        let directory = parent.appendingPathComponent("store", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try FileOHLCVStore(directory: directory)
        try await store.keep([storeBar(0)], market: "BTCUSDT", interval: Fx.minute)
        let siblings = try FileManager.default.contentsOfDirectory(atPath: parent.path)
        #expect(siblings == ["store"])
        #expect(!(try FileManager.default.contentsOfDirectory(atPath: directory.path)).isEmpty)
    }
}
