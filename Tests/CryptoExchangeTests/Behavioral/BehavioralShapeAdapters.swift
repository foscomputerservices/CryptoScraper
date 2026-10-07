// BehavioralShapeAdapters.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// The builder's adapters for step 3's layer-A behavioral suite (AR14): each maps one signature the isolated projector
// invented onto a real member of the libraries. No assertion of a projected file is edited; a test that stays red is
// classified in the builder's ledger with its reason.

import CryptoAsset
import CryptoExchange

import FOSFoundation
import Foundation
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
enum BehavioralAssets {
    static let exponents: [String: Int] = ["BTC": 8, "ETH": 18, "USDC": 6, "USD": 2]
    static let priceBase = "BTC"

    static func asset(_ symbol: String) throws -> Asset {
        try Asset(symbol: symbol, unitExponent: exponents[symbol] ?? 8)
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
// the amended market: each asset's home instance as the holding, and its declared symbol and home decimals as the
// exchange's facts, from the shared registry the step-2 shim above declares into.
extension ExchangeClientMarket {
    init(name: Name, base: Asset, quote: Asset, lotSize: Amount, minimumOrder: Amount,
         maxLeverage: Int?, leverageSet: Int?, isPerpetual: Bool) {
        do {
            let baseDeclaration = try AssetRegistry.shared.declaration(of: base)
            let quoteDeclaration = try AssetRegistry.shared.declaration(of: quote)
            self.init(
                name: name, alternateName: nil,
                baseSymbol: baseDeclaration.symbol, baseDecimals: baseDeclaration.instances[0].decimals,
                quoteSymbol: quoteDeclaration.symbol, quoteDecimals: quoteDeclaration.instances[0].decimals,
                base: try AssetInstance(validating: base.id), quote: try AssetInstance(validating: quote.id),
                lotSize: lotSize, minimumOrder: minimumOrder,
                maxLeverage: maxLeverage, leverageSet: leverageSet, isPerpetual: isPerpetual
            )
        } catch {
            preconditionFailure("ExchangeClientMarket(name:base:quote:…) of an undeclared asset: \(error)")
        }
    }
}

// The projected C30 suite binds the lot and the minimum as non-optional amounts, as C30 declared them before the
// amendment; a market made from two assets always has both, so they read through here. Each reads the amended
// market's stored optional member by reflection: a read by name from here would choose this property again.
// Step 6: declared in a constrained extension so it no longer shadows the stored optional (the re-projection's
// C30_Market reads `lotSize?` and `== nil`); each use takes the one its context asks for.
extension ExchangeClientMarket where Name: Codable {
    var lotSize: Amount { stored("lotSize") }
    var minimumOrder: Amount { stored("minimumOrder") }

    private func stored(_ label: String) -> Amount {
        guard let child = Mirror(reflecting: self).children.first(where: { $0.label == label }),
              let optional = child.value as? Amount?, let amount = optional else {
            preconditionFailure("A market with no \(label)")
        }
        return amount
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

// MARK: Step 6 of the identity PR: the re-projected suites (C30_Market, C31_ExchangeClient)

extension ExchangeClient {
    /// C31's `placeOrder` with the client order id as the code declares it (`clientOrderId: UInt128?` before
    /// `account:`), for a conformer the re-projection writes with its own engine-order-id parameter
    /// (`account:` then `clientOrderId: String`, `C31_ExchangeClient.swift`'s `EchoingClient`): the conformance is
    /// satisfied here, and the projected tests call the conformer's own member. Nothing calls this one.
    func placeOrder(market: MarketName, side: ExchangeClientSide, size: Amount, limit: Price,
                    immediateOrCancel: Bool, reduceOnly: Bool, clientOrderId: UInt128?,
                    account: String) async throws -> ExchangeClientOrderResult<OrderId> {
        throw ExchangeClientError.notOffered(member: "placeOrder")
    }
}

/// The projected `EchoingClient` (`C31_ExchangeClient.swift`) keeps a `Mutex` in a struct, which Swift refuses
/// (`Synchronization.Mutex` is not copyable, the struct is). This module's own `Mutex`, a lock held by reference, is
/// found before the imported one in every file of the target, so the projected construction compiles with the same
/// meaning: one value behind one lock. `ExchangeClientTestSupport.swift`'s two uses read alike.
final class Mutex<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        try lock.withLock { try body(&value) }
    }
}
