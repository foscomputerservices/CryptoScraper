// BehavioralShapeAdapters.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// The builder's adapters for step 3's layer-A behavioral suite of the OHLCV clients (AR14): each maps one signature
// the isolated projector invented onto a real member. No assertion of a projected file is edited; a test that stays
// red is classified in the builder's ledger with its reason. (Adapters.swift is step 2's, for step 2's files.)

import CryptoAsset
import CryptoExchange
@testable import CryptoOHLCV
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The projector's URLSession-shaped seam for a feed client
protocol OHLCVClientSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// An OHLCVClientSession as FOSFoundation's URLSessionProtocol: each task answers from the seam, never the network
struct FeedSessionBridge: URLSessionProtocol {
    let seam: any OHLCVClientSession

    func dataTask(with url: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        dataTask(with: URLRequest(url: url), completionHandler: completionHandler)
    }

    func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) -> URLSessionDataTask {
        let seam = seam
        Task {
            do {
                let (data, response) = try await seam.data(for: request)
                completionHandler(data, response, nil)
            } catch {
                completionHandler(nil, nil, error)
            }
        }
        return Self.inert.dataTask(with: URL(string: "data:,")!)
    }

    static func session(config: URLSessionConfiguration) -> Self {
        fatalError("FeedSessionBridge is made over a seam")
    }

    private static let inert = URLSession(configuration: .ephemeral)
}

/// The projector's shared feed error; each client throws its own typed errors, so a test expecting this is red and
/// classified
enum OHLCVClientError: Error, Equatable {
    case rateLimited(retryAfter: Duration?)
    case malformedResponse
}

// The exact text constructors → the package's one parse. The invented signatures name no exponent and no base, so
// the exponent is the one the symbol has on most of the four feeds and a price's base is BTC at it.
enum FeedAssets {
    static let exponents: [String: Int] = ["BTC": 8, "USDT": 8, "USDC": 6, "USD": 2]

    static func asset(_ symbol: String) throws -> Asset {
        try Asset(symbol: symbol, unitExponent: exponents[symbol] ?? 8)
    }
}

extension Asset {
    init(symbol: String) throws {
        self = try FeedAssets.asset(symbol)
    }
}

extension Amount {
    init(parsing text: String, of asset: Asset) throws {
        self = try WireDecimal(parsing: text).amount(of: stepTwoHome(asset))
    }
}

extension Price {
    init(parsing text: String, in quote: Asset) throws {
        self = try WireDecimal(parsing: text).price(of: stepTwoHome(quote), per: stepTwoHome(FeedAssets.asset("BTC")))
    }
}

// The four conformers' `(session:now:)`.

extension BinanceOHLCVClient {
    /// Binance's exchange information for BTCUSDT passed in (both at Binance's recorded precision 8), so no
    /// exchangeInfo is asked; its holdings come through Binance's table (step 4c of the identity PR)
    init(session: any OHLCVClientSession, now: @escaping @Sendable () -> Date) {
        let btcusdt = try! BinanceMarket(name: .stub(text: "BTCUSDT"), baseSymbol: .stub(text: "BTC"), baseDecimals: 8,
                                         quoteSymbol: .stub(text: "USDT"), quoteDecimals: 8)
        self.init(session: FeedSessionBridge(seam: session), markets: [btcusdt], now: now)
    }
}

extension HyperliquidOHLCVClient {
    init(session: any OHLCVClientSession, now: @escaping @Sendable () -> Date) {
        self.init(session: FeedSessionBridge(seam: session), now: now)
    }
}

extension KrakenOHLCVClient {
    init(session: any OHLCVClientSession, now: @escaping @Sendable () -> Date) {
        self.init(session: FeedSessionBridge(seam: session), now: now)
    }
}

extension CoinbaseOHLCVClient {
    init(session: any OHLCVClientSession, now: @escaping @Sendable () -> Date) {
        self.init(session: FeedSessionBridge(seam: session), now: now)
    }
}

// The projector writes each feed's market as a literal.

extension HyperliquidMarketName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .stub(text: value) }
}

extension KrakenMarketName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .stub(text: value) }
}

extension CoinbaseMarketName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .stub(text: value) }
}

extension BinanceMarketName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .stub(text: value) }
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

// MARK: Step 6 of the identity PR: the re-projected suites (D13, D21, D27, D33, D34, C32 of the identity design)

// Every holding each exchange chain declares: the holdings of its table's rows, imported and overrides, once each.
extension KrakenHolding {
    static var declared: [KrakenHolding] { uniqueHoldings(KrakenExchangeChain.rows.map(\.holding), \.address) }
}

extension BinanceHolding {
    static var declared: [BinanceHolding] { uniqueHoldings(BinanceExchangeChain.rows.map(\.holding), \.address) }
}

extension CoinbaseHolding {
    static var declared: [CoinbaseHolding] { uniqueHoldings(CoinbaseExchangeChain.rows.map(\.holding), \.address) }
}

extension HyperliquidHolding {
    static var declared: [HyperliquidHolding] { uniqueHoldings(HyperliquidExchangeChain.rows.map(\.holding), \.address) }
}

private func uniqueHoldings<Holding>(_ holdings: [Holding], _ address: (Holding) -> String) -> [Holding] {
    var seen: Set<String> = []
    return holdings.filter { seen.insert(address($0)).inserted }
}

// The two row sets of each table (design § 2.7's two files): the imported rows' wire names and the overrides'.
// Coinbase's and Hyperliquid's tables have no imported file; their imported set is empty.
extension KrakenExchangeChain {
    static var importedWireNames: [String] { importedRows.flatMap(\.wireNames) }
    static var overrideWireNames: [String] { overrideRows.flatMap(\.wireNames) }
}

extension BinanceExchangeChain {
    static var importedWireNames: [String] { importedRows.flatMap(\.wireNames) }
    static var overrideWireNames: [String] { overrideRows.flatMap(\.wireNames) }
}

extension CoinbaseExchangeChain {
    static var importedWireNames: [String] { [] }
    static var overrideWireNames: [String] { overrideRows.flatMap(\.wireNames) }
}

extension HyperliquidExchangeChain {
    static var importedWireNames: [String] { [] }
    static var overrideWireNames: [String] { overrideRows.flatMap(\.wireNames) }
}

// C32: Binance's candle client over a recorded session, by the recording's name.

extension BinanceMarketName {
    static let btcUSDT = try! BinanceMarketName(validating: "BTCUSDT")
}

/// A session answering Binance's exchange information from its recording and every klines request from the named
/// recording; a request for a recording this target does not hold is answered 404 with the name, never the network
struct RecordedBinanceSession: Sendable {
    let replay: ReplaySession
    /// The instant the recording was made, the clock the client reads it by
    let recordedAt: Date
}

enum RecordedBinance {
    /// The projected names of the recordings this target holds, and their files under `Resources/`
    private static let files = [
        "klines-BTCUSDT-1d-open": "Binance/klines-btcusdt-1d-latest.json"
    ]

    static func session(answering recording: String) -> RecordedBinanceSession {
        let body = files[recording].map { Recorded.data($0) }
        let replay = ReplaySession { request, _ in
            if request.url!.path.hasSuffix("exchangeInfo") {
                return .ok(Recorded.exchangeInfo)
            }
            guard let body else {
                return Reply(status: 404, body: Data("no recording named \(recording)".utf8), headers: [:])
            }
            return .ok(body)
        }
        return RecordedBinanceSession(replay: replay, recordedAt: Recorded.recordedAt)
    }
}

extension BinanceOHLCVClient {
    init(registry: AssetRegistry, session: RecordedBinanceSession) {
        self.init(session: session.replay, now: { session.recordedAt }, registry: registry)
    }
}

extension Assets {
    /// The projected `Assets.bitcoin`: the code declares Bitcoin's class by hand among the library's declarations,
    /// never generated, so this is that declaration
    static var bitcoin: AssetDeclaration {
        AssetRegistry.libraryDeclarations.first { $0.asset == .btc }!
    }
}

/// The projected D33 imports CryptoAsset and CryptoScraper, which both declare an `Amount` (the 2023 one generic over
/// a contract); in this target every `Amount` written alone is CryptoAsset's, and no file names the 2023 one, so the
/// module's own name settles which
typealias Amount = CryptoAsset.Amount
