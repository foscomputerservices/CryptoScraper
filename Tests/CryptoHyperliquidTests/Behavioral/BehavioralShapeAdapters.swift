// BehavioralShapeAdapters.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// The builder's adapters for step 3's layer-A behavioral suite (AR14): each maps one signature the isolated projector
// invented onto a real member of the libraries. No assertion of a projected file is edited; a test that stays red is
// classified in the builder's ledger with its reason.

import CryptoAsset
import CryptoExchange
import CryptoHyperliquid
import CryptoOHLCV
import CryptoScraper
import FOSFoundation
import Foundation
import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: The session seam → FOSFoundation's mockable session (AR31)

/// The projector's URLSession-shaped seam; its scripted double conforms to it, and BehavioralSessionBridge hands it
/// to a client as the URLSessionProtocol FOSFoundation's fetch takes
protocol ExchangeClientSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// An ExchangeClientSession as FOSFoundation's URLSessionProtocol: each task answers from the seam, never the network
struct BehavioralSessionBridge: URLSessionProtocol {
    let seam: any ExchangeClientSession

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
        fatalError("BehavioralSessionBridge is made over a seam")
    }

    private static let inert = URLSession(configuration: .ephemeral)
}

// MARK: The shared error (the owner's ruling of 2026-10-06: one ExchangeClientError, declared in CryptoExchange)

// The projector invented `ExchangeClientError` with payload-less cases and `.exchange(code:text:)`. The real one is
// C30's: every case carries the exchange's own words. Its files name the invented forms, so each is a static member
// here that makes the real case with no words (or the refusal, for `.exchange`). A client's thrown error carries
// words, and the real type compares them, so a test expecting a payload-less form passes only where the words are
// empty; a test expecting `.rateLimited(retryAfter:)` or `.exchange(code:text:)` passes where the client states the same.
extension ExchangeClientError {
    static var malformedResponse: ExchangeClientError { .malformedResponse(text: "") }
    static var unreachable: ExchangeClientError { .unreachable(text: "") }
    static var unauthorized: ExchangeClientError { .unauthorized(text: "") }
    static func exchange(code: String?, text: String) -> ExchangeClientError { .refused(code: code, text: text) }
}

// MARK: The exact text constructors → the package's one parse (WireDecimal)

/// The exponent each symbol has on this target's exchange, from its recordings
///
/// Step 4b of the identity PR (wiring only): a symbol Hyperliquid's table names is Hyperliquid's declared holding, an
/// asset value naming the holding's instance, so an amount or a price "of" it counts in that holding, as the client's
/// do; any other symbol stays the step-2 shim's asset of its own.
enum BehavioralAssets {
    static let exponents: [String: Int] = ["BTC": 5, "ETH": 4, "USDC": 6]
    static let priceBase = "BTC"

    static func asset(_ symbol: String) throws -> Asset {
        if let holding = try? HyperliquidExchangeChain.default.contract(for: symbol) {
            try HyperliquidExchangeChain.declare(in: .shared)
            if (try? AssetRegistry.shared.decimals(of: AssetInstance(holding))) != nil {
                return try Asset(validating: AssetInstance(holding).id)
            }
        }
        return try Asset(symbol: symbol, unitExponent: exponents[symbol] ?? 8)
    }
}

extension Asset {
    init(symbol: String) throws {
        self = try BehavioralAssets.asset(symbol)
    }
}

extension Amount {
    init(parsing text: String, of asset: Asset) throws {
        self = try WireDecimal(parsing: text).amount(of: stepTwoHome(asset))
    }
}

extension Price {
    /// The invented signature names no base asset: the base is this target's market's (BehavioralAssets/priceBase)
    init(parsing text: String, in quote: Asset) throws {
        self = try WireDecimal(parsing: text).price(of: stepTwoHome(quote), per: stepTwoHome(BehavioralAssets.asset(BehavioralAssets.priceBase)))
    }
}

extension Fraction {
    init(parsing text: String) throws {
        self = try WireDecimal(parsing: text).fraction()
    }
}

// MARK: Hyperliquid's constructors

extension HyperliquidMarketName: ExpressibleByStringLiteral {
    /// The projector writes a market as a literal; it is validated as Hyperliquid spells it
    public init(stringLiteral value: String) {
        do {
            try self.init(validating: value)
        } catch {
            preconditionFailure("A literal market Hyperliquid cannot spell: \(value)")
        }
    }
}

extension HyperliquidAgentKey {
    /// The key from its hex text, "0x" optional
    init(hex: String) throws {
        let digits = Array(hex.hasPrefix("0x") ? hex.dropFirst(2) : Substring(hex))
        guard digits.count % 2 == 0 else { throw ExchangeClientError.unauthorized(text: "The agent key is not 32 bytes of a valid secp256k1 secret") }
        var bytes = Data()
        for index in stride(from: 0, to: digits.count, by: 2) {
            guard let byte = UInt8(String(digits[index..<index + 2]), radix: 16) else { throw ExchangeClientError.unauthorized(text: "The agent key is not 32 bytes of a valid secp256k1 secret") }
            bytes.append(byte)
        }
        try self.init(privateKey: bytes)
    }
}

extension HyperliquidClient {
    /// `session:` through the bridge; `log:` has nothing to receive (the client writes no line); `nonce:` is the clock
    init(credential: HyperliquidCredential?, endpoint: HyperliquidEndpoint, session: any ExchangeClientSession,
         log: @escaping @Sendable (String) -> Void = { _ in }, nonce: (@Sendable () -> UInt64)? = nil) throws {
        let clock: @Sendable () -> Date
        if let nonce {
            clock = { Date(timeIntervalSince1970: Double(nonce()) / 1000) }
        } else {
            clock = { Date() }
        }
        self.init(credential: credential, endpoint: endpoint, session: BehavioralSessionBridge(seam: session), now: clock)
    }
}

/// The projector's signing seam over the client's own signing (AR33): the action read in its key order, hashed,
/// digested and signed exactly as the client does for an order
struct HyperliquidSigner {
    let key: HyperliquidAgentKey

    init(agentKey: HyperliquidAgentKey) {
        self.key = agentKey
    }

    var address: String { key.address }

    struct Signed {
        let actionBytes: Data
        let actionHash: Data
        let typedDataHash: Data
        let r: Data
        let s: Data
        let v: Int
    }

    func sign(actionJSON: Data, nonce: UInt64, vaultAddress: String?, isMainnet: Bool) throws -> Signed {
        let action = OrderedJSON.parse(String(decoding: actionJSON, as: UTF8.self))
        let hash = try HyperliquidSigning.actionHash(action, nonce: nonce, vaultAddress: vaultAddress)
        let digest = HyperliquidSigning.l1Digest(actionHash: hash, isMainnet: isMainnet)
        let signature = key.sign(digest: digest)
        return Signed(actionBytes: Data(action.messagePack), actionHash: Data(hash), typedDataHash: Data(digest),
                      r: Data(signature.r), s: Data(signature.s), v: signature.v)
    }
}

extension HyperliquidClient {
    // The signing fixture names a market as text: each call validates it as Hyperliquid spells it.
    func placeOrder(market: String, side: ExchangeClientSide, size: Amount, limit: Price, immediateOrCancel: Bool, reduceOnly: Bool,
                    account: String) async throws -> ExchangeClientOrderResult<HyperliquidOrderId> {
        try await placeOrder(market: HyperliquidMarketName(validating: market), side: side, size: size, limit: limit,
                             immediateOrCancel: immediateOrCancel, reduceOnly: reduceOnly, account: account)
    }

    func cancelOrder(_ id: HyperliquidOrderId, market: String, account: String) async throws {
        try await cancelOrder(id, market: HyperliquidMarketName(validating: market), account: account)
    }

    func setLeverage(_ leverage: Int, market: String, isolated: Bool, account: String) async throws {
        try await setLeverage(leverage, market: HyperliquidMarketName(validating: market), isolated: isolated, account: account)
    }
}

// MARK: The book's two volumes (the owner's ruling of 2026-10-06: C30's book carries baseVolume and quoteVolume)

// The projector's files name one `volume` and build a book with it. Wiring only, no assertion changed: its one volume
// reads as the quote turnover (the projector's own reading was the notional), and its one-volume book stands that
// amount as both.
extension ExchangeClientBook {
    var volume: Amount { quoteVolume }

    init(market: Name, mid: Price, bestBid: Price, bestAsk: Price, volume: Amount, readAt: Date) {
        self.init(market: market, mid: mid, bestBid: bestBid, bestAsk: bestAsk, baseVolume: volume, quoteVolume: volume, readAt: readAt)
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

private func stepTwoDeclaration(of asset: Asset) -> AssetDeclaration {
    do {
        return try AssetRegistry.shared.declaration(of: asset)
    } catch {
        preconditionFailure("\(asset.id) is not declared: \(error)")
    }
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

    var symbol: AssetSymbol { stepTwoDeclaration(of: self).symbol }
    var unitExponent: Int { stepTwoDeclaration(of: self).instances[0].decimals }
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

// MARK: Step 4a of the identity PR: C30's market amended (design § 5.3; wiring only)

// The projected suites make a market from two assets and two amounts, C30's shape before the amendment. Wired onto
// the amended market: each asset's instance as the holding (step 4b: a Hyperliquid holding where BehavioralAssets
// names one, else the asset's home), and that instance's declared symbol and decimals as the exchange's facts, from
// the shared registry.
extension ExchangeClientMarket {
    init(name: Name, base: Asset, quote: Asset, lotSize: Amount, minimumOrder: Amount,
         maxLeverage: Int?, leverageSet: Int?, isPerpetual: Bool) {
        do {
            let registry = AssetRegistry.shared
            let baseInstance = try AssetInstance(validating: base.id)
            let quoteInstance = try AssetInstance(validating: quote.id)
            func symbol(of instance: AssetInstance) throws -> AssetSymbol {
                let declaration = try registry.declaration(of: registry.asset(of: instance))
                return declaration.instances.first { $0.instance == instance }?.symbol ?? declaration.symbol
            }
            self.init(
                name: name, alternateName: nil,
                baseSymbol: try symbol(of: baseInstance), baseDecimals: try registry.decimals(of: baseInstance),
                quoteSymbol: try symbol(of: quoteInstance), quoteDecimals: try registry.decimals(of: quoteInstance),
                base: baseInstance, quote: quoteInstance,
                lotSize: lotSize, minimumOrder: minimumOrder,
                maxLeverage: maxLeverage, leverageSet: leverageSet, isPerpetual: isPerpetual
            )
        } catch {
            preconditionFailure("ExchangeClientMarket(name:base:quote:…) of an undeclared asset: \(error)")
        }
    }
}

// MARK: The client gaps (CryptoScraper's identity PR): C31's client order id and C30's open order carrying it back

// The projected suites call placeOrder and make an open order in C31's and C30's earlier shapes: each is the real
// member with no client order id (wiring only).
extension ExchangeClient {
    func placeOrder(market: MarketName, side: ExchangeClientSide, size: Amount, limit: Price,
                    immediateOrCancel: Bool, reduceOnly: Bool, account: String) async throws -> ExchangeClientOrderResult<OrderId> {
        try await placeOrder(market: market, side: side, size: size, limit: limit, immediateOrCancel: immediateOrCancel,
                             reduceOnly: reduceOnly, clientOrderId: nil, account: account)
    }
}

extension ExchangeClientOpenOrder {
    init(id: OrderId, market: Name, side: ExchangeClientSide, units: Amount) {
        self.init(id: id, market: market, side: side, units: units, clientOrderId: nil)
    }
}

// MARK: Step 6 of the identity PR: the re-projected suites (D53, D13, C31's echo), wiring only

/// The projected files import CryptoAsset and CryptoScraper, which both declare an `Amount` (the 2023 one generic over
/// a contract); every `Amount` they write alone is CryptoAsset's, so the module's own name settles which. The 2023
/// one is still `CryptoScraper.Amount`.
typealias Amount = CryptoAsset.Amount

/// A member the re-projection calls that the code does not declare: thrown by the compile-only shims below, each
/// behind a test disabled in place with its classification (never reached by a running test)
struct NotDeclared: Error, CustomStringConvertible {
    let member: String
    var description: String { "\(member) is not declared; see the identity ledger" }
}

/// The recorded Hyperliquid answers by the names the projected files give them: a session over this target's recordings,
/// answering each request from the recording of its endpoint, as the contract tests' route does. A name this target
/// holds no recording of is answered 404 with the name, never the network. Each request is noted under the test
/// that asked it.
struct RecordedHyperliquidSession: Sendable {
    let replay: ReplaySession
}

enum RecordedHyperliquid {
    /// The projected names of the recordings this target holds
    private static let held: Set<String> = ["meta", "clearinghouseState", "userNonFundingLedgerUpdates", "exchange-order"]
    /// The projected names of single recordings read as bytes, and their files under `Resources/`
    private static let files: [String: String] = ["userNonFundingLedgerUpdates": "Hyperliquid/ledger-sub.json"]

    static func session(answering recording: String) -> RecordedHyperliquidSession {
        let route = Hyperliquid.route(exchange: "exchange-order-resting.json")
        let isHeld = held.contains(recording)
        return RecordedHyperliquidSession(replay: ReplaySession { request, index in
            note(request)
            guard isHeld else {
                return Reply(status: 404, body: Data("no recording named \(recording)".utf8), headers: [:])
            }
            return route(request, index)
        })
    }

    static func data(_ recording: String) -> Data {
        guard let file = files[recording] else {
            preconditionFailure("No recording named \(recording) in this target")
        }
        return Recording.body(file)
    }

    /// The body of the last request the running test's recorded session was sent
    static var lastRequestBody: String {
        bodies.withLock { $0[Test.current?.id.description ?? ""] } ?? ""
    }

    private static let bodies = Locked<[String: String]>([:])

    private static func note(_ request: URLRequest) {
        bodies.withLock { $0[Test.current?.id.description ?? ""] = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? "" }
    }
}

/// A value behind a lock, for the recorded sessions' notes
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.withLock { body(&value) }
    }
}

extension HyperliquidClient {
    init(credential: HyperliquidCredential?, endpoint: HyperliquidEndpoint, session: RecordedHyperliquidSession,
         registry: AssetRegistry) {
        self.init(credential: credential, endpoint: endpoint, session: session.replay, now: { Hyperliquid.recordedAt },
                  registry: registry)
    }
}

extension HyperliquidAgentKey {
    /// The signing vectors' documented agent key, as the contract tests use it
    static func stub() -> Self { VectorFile.loaded.key }
}

/// C31's `placeOrder` as the re-projection writes it, `account:` then a `String` engine order id. NOT DECLARED: the
/// code's is `clientOrderId: UInt128?` before `account:` (C22's 128-bit token), and a text such as "quarry-42" has
/// no 128-bit reading, so no wiring maps it; the tests that call this are disabled in place, classified.
extension ExchangeClient {
    func placeOrder(market: MarketName, side: ExchangeClientSide, size: Amount, limit: Price,
                    immediateOrCancel: Bool, reduceOnly: Bool, account: String,
                    clientOrderId: String) async throws -> ExchangeClientOrderResult<OrderId> {
        throw NotDeclared(member: "placeOrder(…, account:, clientOrderId: String)")
    }
}

/// The echoed id compared with the projected `String`: compile-only (C30's open order's `clientOrderId` is a
/// `UInt128?`), behind tests disabled in place
func == (lhs: UInt128?, rhs: String) -> Bool {
    preconditionFailure("ExchangeClientOpenOrder.clientOrderId is a UInt128?, never a String; see the identity ledger")
}

/// The units check as the re-projection writes it. NOT DECLARED: the code's units check is inside `markets()`, which
/// throws `AssetRegistryError.decimalsChanged` when the exchange states other decimals; no member returns findings
struct ExchangeUnitsFinding: Hashable, Sendable {
    let instance: AssetInstance
    let stated: Int
    let declared: Int
}

extension HyperliquidClient {
    func unitsCheck() async throws -> [ExchangeUnitsFinding] {
        throw NotDeclared(member: "HyperliquidClient.unitsCheck()")
    }
}

/// The scanner's typed error as the re-projection names it. NOT DECLARED: the code's unconfigured scanner throws
/// `ExchangeClientError.unauthorized(text:)` naming the exchange; this type is only for the projected files to compile
enum ExchangeScannerError: Error, Hashable {
    case unconfigured(exchange: String)
}

/// The 2023 amount's contract as the re-projection names it: the code's member is `currency`. The 2023 `Amount`
/// cannot be named here (the module CryptoScraper's enum `CryptoScraper` shadows `CryptoScraper.Amount`, and this
/// target's `Amount` is CryptoAsset's), so the stored `currency` is read by reflection, as the step-4a block reads a
/// market's stored member; on any other value it is `nil`.
extension Stubbable where Self: Comparable & Codable & Hashable {
    var contract: HyperliquidHolding? {
        Mirror(reflecting: self).children.first { $0.label == "currency" }?.value as? HyperliquidHolding
    }
}
