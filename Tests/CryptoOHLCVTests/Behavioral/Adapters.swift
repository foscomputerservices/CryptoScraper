// Adapters.swift — the builder's adapters for the behavioral suite, under THE WIRING RULE
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// Each declaration here maps one invented signature of BehavioralAssumptions.md onto one real member of the
// libraries. No assertion of the suite is touched. The same file is in CryptoOHLCVTests/Behavioral and
// CryptoReferenceTests/Behavioral, since BehavioralFixtures.swift, which both carry, names every adapter.
//
// The map:
//   OHLCVStore (protocol: bars / keep bars / gaps / keep gaps)  → OHLCVHistoryStore (history / append / lastBar), through StoreBridge
//   OHLCVGap(after:before:)                                     → OHLCVHistoryGap(lastBarOpenTime:nextBarOpenTime:missingBarCount:)
//   FileOHLCVStore(directory:)                                  → OHLCVHistoryFileStore<String>(directory:)
//   OHLCVRetrieval(client:store:sleep:)                         → OHLCVHistoryRetrieval(client:store:backoff:sleep:)
//   OHLCVRetrieval.fetch(market:interval:from:through:)         → OHLCVHistoryRetrieval.retrieve(market:interval:from:through:)
//   OHLCVRetrievalReport.added / .gaps                          → OHLCVHistoryRetrievalResult.bars / .gaps
//   ReferenceClientAsset.tier                                   → ReferenceClientAsset.rank
//   ReferenceClientAsset.sector                                 → no surface member (UNRATIFIED: rank and tags); records an issue
//   ReferenceClientAsset.stub(symbol:name:sector:tier:)         → ReferenceClientAsset.stub(symbol:name:rank:…)
//   behavioralBinanceClient(session:now:)                       → BinanceOHLCVClient(session:now:)
//   behavioralBinanceMarket(_:base:quote:)                      → BinanceMarket(name:base:quote:), answered as /api/v3/exchangeInfo
//   behavioralCoinMarketCapClient(session:)                     → CoinMarketCapClient(apiKey:session:)
//   behavioralExchangeError(_:)                                 → BinanceAPIError / CoinMarketCapError
//   behavioralLimit(_:)                                         → BinanceLimitError (OHLCVClientLimitError)

import CryptoAsset
import CryptoOHLCV
import CryptoReference
import FOSFoundation
import Foundation
import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - The store protocol

protocol OHLCVStore: Sendable {
    func bars(market: String, interval: BarInterval) async throws -> [OHLCVClientBar]
    func keep(_ bars: [OHLCVClientBar], market: String, interval: BarInterval) async throws
    func gaps(market: String, interval: BarInterval) async throws -> [OHLCVGap]
    func keep(_ gaps: [OHLCVGap], market: String, interval: BarInterval) async throws
}

struct OHLCVGap: Hashable, Sendable {
    let after: Date
    let before: Date

    init(after: Date, before: Date) {
        self.after = after
        self.before = before
    }

    init(_ gap: OHLCVHistoryGap) {
        self.init(after: gap.lastBarOpenTime, before: gap.nextBarOpenTime)
    }

    // The library's gap carries its missing-bar count, a fact of the interval.
    func historyGap(interval: BarInterval) -> OHLCVHistoryGap {
        let step = Int64(interval.count) * intervalUnitMilliseconds(interval.unit)
        let difference = ms(before) - ms(after)
        return OHLCVHistoryGap(lastBarOpenTime: after, nextBarOpenTime: before, missingBarCount: Int(difference / step - 1))
    }
}

private func intervalUnitMilliseconds(_ unit: BarInterval.Unit) -> Int64 {
    switch unit {
    case .minute: 60_000
    case .hour: 3_600_000
    case .day: 86_400_000
    case .week: 604_800_000
    }
}

/// The shipped file store, keyed by the market's text
struct FileOHLCVStore: OHLCVStore {
    let store: OHLCVHistoryFileStore<String>

    init(directory: URL) throws {
        self.store = OHLCVHistoryFileStore<String>(directory: directory)
    }

    func bars(market: String, interval: BarInterval) async throws -> [OHLCVClientBar] {
        try await store.history(market: market, interval: interval).bars
    }

    func keep(_ bars: [OHLCVClientBar], market: String, interval: BarInterval) async throws {
        try await store.append(bars, gaps: [], market: market, interval: interval)
    }

    func gaps(market: String, interval: BarInterval) async throws -> [OHLCVGap] {
        try await store.history(market: market, interval: interval).gaps.map(OHLCVGap.init)
    }

    func keep(_ gaps: [OHLCVGap], market: String, interval: BarInterval) async throws {
        try await store.append([], gaps: gaps.map { $0.historyGap(interval: interval) }, market: market, interval: interval)
    }
}

/// The suite's store seen as the library's store protocol, the client's market name read as its text
struct StoreBridge<Store: OHLCVStore, MarketName: Hashable & Sendable & CustomStringConvertible>: OHLCVHistoryStore {
    let store: Store

    func lastBar(market: MarketName, interval: BarInterval) async throws -> OHLCVClientBar? {
        try await store.bars(market: market.description, interval: interval).last
    }

    func append(_ bars: [OHLCVClientBar], gaps: [OHLCVHistoryGap], market: MarketName, interval: BarInterval) async throws {
        try await store.keep(bars, market: market.description, interval: interval)
        if !gaps.isEmpty {
            try await store.keep(gaps.map(OHLCVGap.init), market: market.description, interval: interval)
        }
    }

    func history(market: MarketName, interval: BarInterval) async throws -> OHLCVHistory {
        OHLCVHistory(
            bars: try await store.bars(market: market.description, interval: interval),
            gaps: try await store.gaps(market: market.description, interval: interval).map { $0.historyGap(interval: interval) }
        )
    }
}

// MARK: - The retrieval

struct OHLCVRetrievalReport: Sendable {
    let added: [OHLCVClientBar]
    let gaps: [OHLCVGap]
}

struct OHLCVRetrieval<Client: OHLCVClient, Store: OHLCVStore>: Sendable where Client.MarketName: CustomStringConvertible {
    let retrieval: OHLCVHistoryRetrieval<Client, StoreBridge<Store, Client.MarketName>>

    init(client: Client, store: Store, sleep: @escaping @Sendable (Duration) async throws -> Void) {
        self.retrieval = OHLCVHistoryRetrieval(client: client, store: StoreBridge(store: store), sleep: sleep)
    }

    func fetch(market: Client.MarketName, interval: BarInterval, from: Date, through: Date) async throws -> OHLCVRetrievalReport {
        let result = try await retrieval.retrieve(market: market, interval: interval, from: from, through: through)
        return OHLCVRetrievalReport(added: result.bars, gaps: result.gaps.map(OHLCVGap.init))
    }
}

// MARK: - The reference value

extension ReferenceClientAsset {
    var tier: Int {
        rank
    }

    // No surface member: the value hands up rank and tags, and the sector is the caller's reading (UNRATIFIED).
    var sector: String {
        Issue.record("no surface member: ReferenceClientAsset.sector (UNRATIFIED: the value hands up rank and tags)")
        return ""
    }

    static func stub(symbol: AssetSymbol = .stub(), name: String = "Fred Flintstone", sector: String? = nil, tier: Int = 42) -> Self {
        if sector != nil {
            Issue.record("no surface member: ReferenceClientAsset.stub(sector:)")
        }
        return .stub(symbol: symbol, name: name, rank: tier)
    }
}

// MARK: - The sessions and the clients

// The markets the suite has named, with their assets, answered to the client as Binance's exchangeInfo would.
private final class MarketRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var markets: [String: BinanceMarket] = [:]

    func keep(_ market: BinanceMarket) {
        lock.withLock { markets[market.name.text] = market }
    }

    func exchangeInfo(_ symbol: String?) -> Data {
        let known = lock.withLock { symbol.flatMap { markets[$0] } }
        guard let known else {
            return Data(#"{"code":-1121,"msg":"Invalid symbol."}"#.utf8)
        }
        let body = #"{"symbols":[{"symbol":"\#(known.name.text)","baseAsset":"\#(known.base.symbol.text)","baseAssetPrecision":\#(known.base.unitExponent),"quoteAsset":"\#(known.quote.symbol.text)","quoteAssetPrecision":\#(known.quote.unitExponent)}]}"#
        return Data(body.utf8)
    }
}

private let registry = MarketRegistry()

func behavioralBinanceMarket(_ symbol: String, base: Asset, quote: Asset) -> BinanceOHLCVClient.MarketName {
    let name = try! BinanceMarketName(validating: symbol)
    registry.keep(BinanceMarket(name: name, base: base, quote: quote))
    return name
}

// The suite's async session as FOSFoundation's mockable session. exchangeInfo is answered from the markets the
// suite named and never reaches the suite's session, whose requests the tests count.
private struct BehavioralURLSession: URLSessionProtocol {
    let session: any BehavioralSession

    func dataTask(
        with url: URL,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        dataTask(with: URLRequest(url: url), completionHandler: completionHandler)
    }

    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void
    ) -> URLSessionDataTask {
        let session = session
        if request.url!.path.hasSuffix("/exchangeInfo") {
            let symbol = queryItems(of: request)["symbol"]
            let body = registry.exchangeInfo(symbol)
            let status = body.first == UInt8(ascii: "{") && String(decoding: body, as: UTF8.self).contains("\"symbols\"") ? 200 : 400
            completionHandler(body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                                    headerFields: ["Content-Type": "application/json"]), nil)
        } else {
            Task {
                do {
                    let (data, response) = try await session.data(for: request)
                    completionHandler(data, response, nil)
                } catch {
                    completionHandler(nil, nil, error)
                }
            }
        }
        return Self.inert.dataTask(with: URL(string: "data:,")!)
    }

    static func session(config: URLSessionConfiguration) -> Self {
        fatalError("BehavioralURLSession is made over the suite's session")
    }

    private static let inert = URLSession(configuration: .ephemeral)
}

func behavioralBinanceClient(session: any BehavioralSession, now: @escaping @Sendable () -> Date) -> BinanceOHLCVClient {
    BinanceOHLCVClient(session: BehavioralURLSession(session: session), now: now)
}

func behavioralCoinMarketCapClient(session: any BehavioralSession) -> CoinMarketCapClient {
    CoinMarketCapClient(apiKey: "behavioral-key", session: BehavioralURLSession(session: session))
}

// MARK: - The typed errors

func behavioralExchangeError(_ error: any Error) -> BehavioralExchangeError? {
    if let binance = error as? BinanceAPIError {
        return BehavioralExchangeError(code: binance.code, message: binance.message)
    }
    if let cmc = error as? CoinMarketCapError {
        return BehavioralExchangeError(code: cmc.code, message: cmc.message)
    }
    return nil
}

func behavioralLimit(_ error: any Error) -> BehavioralLimit? {
    (error as? any OHLCVClientLimitError).map { BehavioralLimit(retryAfter: $0.retryAfter) }
}

// MARK: - A compile shim for the suite's own code

// `#expect(bars.allSatisfy(\.isClosed))` does not compile under this toolchain: the macro passes the key path as a
// function argument to the rethrowing `allSatisfy`, which it then treats as throwing. This overload takes the key
// path as a key path and does not throw, so the assertion compiles as written and means what it says.
extension Sequence {
    func allSatisfy(_ keyPath: KeyPath<Element, Bool>) -> Bool {
        allSatisfy { $0[keyPath: keyPath] }
    }
}
