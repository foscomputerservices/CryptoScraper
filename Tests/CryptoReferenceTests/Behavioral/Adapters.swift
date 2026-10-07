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
//   behavioralBinanceMarket(_:base:quote:)                      → BinanceMarketName, its assets answered as /api/v3/exchangeInfo
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
// Step 4c of the identity PR: the client no longer takes a market's assets from its caller, so the suite's market is
// its name and the assets' names, and the answer states each asset's precision as Binance does: a declared Binance
// holding's decimals where Binance's table names the asset, else the exponent the suite declared it at.
private final class MarketRegistry: @unchecked Sendable {
    private struct Named {
        let name: BinanceMarketName
        let base: Asset
        let quote: Asset
    }

    private let lock = NSLock()
    private var markets: [String: Named] = [:]

    func keep(_ name: BinanceMarketName, base: Asset, quote: Asset) {
        lock.withLock { markets[name.text] = Named(name: name, base: base, quote: quote) }
    }

    func exchangeInfo(_ symbol: String?) -> Data {
        let known = lock.withLock { symbol.flatMap { markets[$0] } }
        guard let known else {
            return Data(#"{"code":-1121,"msg":"Invalid symbol."}"#.utf8)
        }
        let body = #"{"symbols":[{"symbol":"\#(known.name.text)","baseAsset":"\#(known.base.symbol.text)","baseAssetPrecision":\#(Self.precision(of: known.base)),"quoteAsset":"\#(known.quote.symbol.text)","quoteAssetPrecision":\#(Self.precision(of: known.quote))}]}"#
        return Data(body.utf8)
    }

    private static func precision(of asset: Asset) -> Int {
        do {
            _ = try BinanceExchangeChain.declaredInstance(wireName: asset.symbol.text, decimals: asset.unitExponent, in: .shared)
            return asset.unitExponent
        } catch AssetRegistryError.decimalsChanged(let holding) {
            return (try? AssetRegistry.shared.decimals(of: holding)) ?? asset.unitExponent
        } catch {
            return asset.unitExponent
        }
    }
}

private let registry = MarketRegistry()

func behavioralBinanceMarket(_ symbol: String, base: Asset, quote: Asset) -> BinanceOHLCVClient.MarketName {
    let name = try! BinanceMarketName(validating: symbol)
    registry.keep(name, base: base, quote: quote)
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

// MARK: Step 2 of the identity PR: the old CryptoAsset surface over the new one (wiring only; step 4 rewrites)

// An asset this target's tests declare by a symbol and an exponent is declared, here, as an asset of its own on the
// reserved-fake `behave:0` chain, its address the symbol, the exponent and a digest of its units, in the shared
// registry the clients read; an amount or a price "of an asset" counts in that asset's home instance. The clients
// themselves no longer mint an asset from the wire (step 4), so a test that reads one from a client is red until then.

private func stepTwoHome(_ asset: Asset) -> AssetInstance {
    do {
        return try AssetInstance(validating: asset.id)
    } catch {
        preconditionFailure("\(asset.id) is no instance: \(error)")
    }
}

// Step 4c: the declaration of the class the asset's instance is in, so an asset value naming a Binance holding (below)
// reads its class's units too.
private func stepTwoDeclaration(of asset: Asset) -> AssetDeclaration {
    do {
        return try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: stepTwoHome(asset)))
    } catch {
        preconditionFailure("\(asset.id) is not declared: \(error)")
    }
}

// Step 4c: the instance's own entry, its symbol and decimals.
private func stepTwoInstance(of asset: Asset) -> AssetDeclaration.Instance {
    guard let entry = stepTwoDeclaration(of: asset).instances.first(where: { $0.instance == stepTwoHome(asset) }) else {
        preconditionFailure("\(asset.id) is no declared instance")
    }
    return entry
}

private func stepTwoDigest(_ text: String) -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x0000_0100_0000_01b3
    }
    return String(hash, radix: 16)
}

extension Asset {
    init(symbol: AssetSymbol, unitExponent: Int,
         wholeUnit: UnitDescription? = nil, baseUnit: UnitDescription? = nil,
         between: [Unit] = [], displayUnit: Unit? = nil) throws {
        struct Units: Encodable {
            let wholeUnit: UnitDescription?
            let baseUnit: UnitDescription?
            let between: [Unit]
            let displayUnit: Unit?
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        // Step 4c of the identity PR: the suite's markets are Binance's, and the client prices in Binance's declared
        // holdings, never in an asset the caller declares; an asset declared by a symbol Binance's table names, at the
        // decimals Binance's holding is declared at, with no units of its own, is that holding.
        try BinanceExchangeChain.declare(in: .shared)
        if wholeUnit == nil, baseUnit == nil, between.isEmpty, displayUnit == nil,
           let holding = try? BinanceExchangeChain.declaredInstance(wireName: symbol.text, decimals: unitExponent, in: .shared) {
            self = try Asset(validating: holding.id)
            return
        }
        let units = try encoder.encode(Units(wholeUnit: wholeUnit, baseUnit: baseUnit, between: between, displayUnit: displayUnit))
        let address = "\(symbol.text)-\(unitExponent)-\(stepTwoDigest(String(decoding: units, as: UTF8.self)))"
        let instance = try AssetInstance(validating: "behave:0:" + address)
        let home = try AssetDeclaration.Instance(instance: instance, decimals: unitExponent, symbol: symbol)
        let asset = try Asset(validating: instance.id)
        try AssetRegistry.shared.add([AssetDeclaration(
            asset: asset, tokenName: symbol.text, symbol: symbol,
            wholeUnit: wholeUnit, baseUnit: baseUnit, between: between, displayUnit: displayUnit,
            instances: [home]
        )])
        self = asset
    }

    init(symbol: String, unitExponent: Int,
         wholeUnit: UnitDescription? = nil, baseUnit: UnitDescription? = nil,
         between: [Unit] = [], displayUnit: Unit? = nil) throws {
        try self.init(symbol: AssetSymbol(validating: symbol), unitExponent: unitExponent,
                      wholeUnit: wholeUnit, baseUnit: baseUnit, between: between, displayUnit: displayUnit)
    }

    var symbol: AssetSymbol { stepTwoInstance(of: self).symbol }
    var unitExponent: Int { stepTwoInstance(of: self).decimals }
    var wholeUnit: Unit { stepTwoDeclaration(of: self).wholeUnit }
    var baseUnit: Unit? { stepTwoDeclaration(of: self).baseUnit }
    var units: [Unit] { stepTwoDeclaration(of: self).units }
    func unit(named name: String) -> Unit? { stepTwoDeclaration(of: self).unit(named: name) }
}

extension AssetError {
    static func unitExponentOutOfRange(_ exponent: Int) -> AssetError { .decimalsOutOfRange(exponent) }
}

extension AmountError {
    static func belowBaseUnit(_ text: String, unitExponent: Int) -> AmountError { .belowBaseUnit(text, decimals: unitExponent) }
}

extension Amount {
    init(baseUnits: Int128, asset: Asset) {
        self.init(baseUnits: baseUnits, of: stepTwoHome(asset))
    }

    init(whole: Int, of asset: Asset) {
        do {
            try self.init(whole: whole, of: stepTwoHome(asset))
        } catch {
            preconditionFailure("Amount(whole:of:): \(error)")
        }
    }

    var asset: Asset {
        do {
            return try Asset(validating: instance.id)
        } catch {
            preconditionFailure("\(instance.id) is no asset: \(error)")
        }
    }

    static func zero(of asset: Asset) -> Self { .zero(of: stepTwoHome(asset)) }
}

extension Price {
    init(_ quote: Amount, per base: Asset) {
        do {
            try self.init(quote, per: stepTwoHome(base))
        } catch {
            preconditionFailure("Price(_:per:): \(error)")
        }
    }

    init(_ quote: Amount, per size: Amount) {
        do {
            try self.init(quote, per: size, in: .shared)
        } catch {
            preconditionFailure("Price(_:per:): \(error)")
        }
    }

    func cost(of size: Amount) -> Amount {
        do {
            return try cost(of: size, in: .shared)
        } catch {
            preconditionFailure("Price.cost(of:): \(error)")
        }
    }
}

func == (lhs: AssetInstance, rhs: Asset) -> Bool { lhs.id == rhs.id }
func == (lhs: Asset, rhs: AssetInstance) -> Bool { lhs.id == rhs.id }
func != (lhs: AssetInstance, rhs: Asset) -> Bool { lhs.id != rhs.id }
func != (lhs: Asset, rhs: AssetInstance) -> Bool { lhs.id != rhs.id }
func == (lhs: AssetInstance?, rhs: Asset) -> Bool { lhs?.id == rhs.id }
func == (lhs: Asset?, rhs: AssetInstance) -> Bool { lhs?.id == rhs.id }
