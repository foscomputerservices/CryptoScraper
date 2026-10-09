// CoinbaseExchangeChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

// CryptoAsset's names are imported one by one, so `Amount` here is CryptoScraper's 2023 amount, the one its scanner
// protocol states; CryptoAsset's amount is never named in this file.
import enum CryptoAsset.EXCHANGE
import enum CryptoAsset.AssetError
import enum CryptoAsset.AssetRegistryError
import class CryptoAsset.AssetRegistry
import struct CryptoAsset.Asset
import struct CryptoAsset.AssetDeclaration
import struct CryptoAsset.AssetInstance
import struct CryptoAsset.AssetSymbol
import struct CryptoAsset.CurrencyDeclaration
import enum CryptoAsset.ISO4217
import CryptoExchange
import CryptoScraper
import FOSFoundation
import Foundation
import Synchronization

// Design § 1.3, the second placement of 2026-10-07: Coinbase as a chain of the 2023 protocols, declared here beside
// Coinbase's market name and errors, so both of Coinbase's clients (its candle client here, its exchange client
// in CryptoCoinbase) work in the same holding constants. This file is the only place Coinbase's strings are
// written: its wire names, in one table, and its holdings' keys, decimals and symbols, as constants.

/// Coinbase as a chain: its holdings are its contracts, its client is its scanner
///
/// ```swift
/// CoinbaseExchangeChain.default.id                            // "exchange:coinbase"
/// try CoinbaseExchangeChain.default.contract(for: "BTC")      // CoinbaseHolding.btc
/// ```
public final class CoinbaseExchangeChain: CryptoChain, Sendable {
    /// In the library's own `exchange` namespace: no CAIP-2 namespace exists for exchanges
    public let id: String = EXCHANGE.Coinbase.chainId

    /// "Coinbase"
    public let userReadableName: String = "Coinbase"

    /// Coinbase's USD, the holding an account's value is stated in
    public let mainContract: CoinbaseHolding!

    /// Never `nil` (the owner's word, 2026-10-07): made without a client, configured with one through
    /// ``CoinbaseScanner/configure(client:)``
    public let scanner: CoinbaseScanner

    /// The one Coinbase chain
    public static let `default`: CoinbaseExchangeChain = .init()

    // Made, the chain is registered with `BlockChains`, so `contract(of:)` answers for its holdings (design § 1.3)
    private init() {
        self.mainContract = .usd
        self.scanner = CoinbaseScanner()
        BlockChains.register(self)
    }

    /// The holding Coinbase names `address` on the wire, a product's currency id ("BTC", "USD")
    ///
    /// - Throws: ``AssetError/malformedIdentity(_:)`` for a name the table lacks: a finding, never a holding minted
    ///   from the string
    public func contract(for address: String) throws -> CoinbaseHolding {
        guard let holding = Self.table[address] else {
            throw AssetError.malformedIdentity(address)
        }
        return holding
    }

    /// The declared holdings, each with its symbol and its asset's name
    public var chainTokenInfos: Set<SimpleTokenInfo<CoinbaseHolding>> {
        Set(Self.rows.map(Self.tokenInfo(of:)))
    }

    /// The declared holding whose key is `address`, with its symbol and its asset's name; `nil` for any other address
    public func tokenInfo(for address: String) -> SimpleTokenInfo<CoinbaseHolding>? {
        Self.rows.first { $0.holding.address == address }.map(Self.tokenInfo(of:))
    }

    /// Nothing to load: Coinbase's holdings are declared constants, never read from an aggregator
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {}
}

/// A holding of an asset on Coinbase, or an account on it, by the library's key for it
///
/// The constants (``btc``, ``eth``, ``usd``) are what every call works in; Coinbase's own names for them reach them
/// only through ``CoinbaseExchangeChain/contract(for:)``. A portfolio is an account on it, by its uuid (design § 1.3).
///
/// ```swift
/// AssetInstance(CoinbaseHolding.btc).id      // "exchange:coinbase:BTC"
/// CoinbaseHolding.btc.wireName               // "BTC", the currency id Coinbase accepts in a request
/// ```
public struct CoinbaseHolding: CryptoContract, Codable, Stubbable, Sendable {
    /// One unit, the base unit, exponent 0: one ladder per exchange cannot hold every holding's decimals, which the
    /// statement holds (design § 1.3); a holding is never rendered through `CurrencyFormatter`
    public enum Units: CurrencyUnits {
        case base

        public static var chainBaseUnits: Self { .base }
        public static var defaultDisplayUnits: Self { .base }
    }

    public typealias Chain = CoinbaseExchangeChain

    /// The library's key for the holding ("BTC"), declared once, or a portfolio's uuid
    public let address: String

    /// A holding or an account by the library's key for it, never by a name read from Coinbase's wire: those reach
    /// a holding through ``CoinbaseExchangeChain/contract(for:)``
    public init(address: String) {
        self.address = address
    }

    /// The one name Coinbase accepts for it on the wire, from the table; an account's name is its own
    public var wireName: String {
        CoinbaseExchangeChain.rows.first { $0.holding == self }?.wireNames.first ?? address
    }
}

public extension CoinbaseHolding {
    /// Bitcoin on Coinbase, "BTC", at 8 decimals, in `Asset.btc`
    static let btc = CoinbaseHolding(address: "BTC")
    /// Ether on Coinbase, "ETH", at 8 decimals, in `Asset.eth`
    static let eth = CoinbaseHolding(address: "ETH")
    /// The dollar on Coinbase, "USD", at 2 decimals, in `Asset.usd`
    static let usd = CoinbaseHolding(address: "USD")
}

public extension CoinbaseHolding {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.address = try container.decode(String.self, forKey: .address)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(address, forKey: .address)
    }

    private enum CodingKeys: String, CodingKey {
        case address
    }
}

public extension CoinbaseHolding {
    /// An account on the reserved fake: no exchange names a holding FRED
    static func stub() -> Self { .stub(address: "FRED") }

    /// A holding or an account by any key, FRED by default
    static func stub(address: String = "FRED") -> Self {
        .init(address: address)
    }
}

public extension CoinbaseHolding.Units {
    /// 1: the base unit alone, exponent 0
    var divisorFromBase: UInt128 { 1 }
    /// None: a holding is rendered by its declared units (C10), never by this ladder
    var displayIdentifier: String { "" }
    /// 0: base units are whole
    var displayFractionDigits: Int { 0 }
}

// MARK: The table

extension CoinbaseExchangeChain {
    // One row per holding: its constant, Coinbase's name for it, and its decimals and symbol, the decimals as the
    // recorded products answer of 2026-10-06 states the holding's precision, its finest increment (BTC-USD's and
    // ETH-USD's base_increment "0.00000001", their quote_increment "0.01"): Coinbase states no decimals of its own, and
    // the one recording of its balances is documentation-derived; the asset it is an instance of. The wire is checked
    // against these, never the source of them.
    struct Row: Sendable {
        let holding: CoinbaseHolding
        let wireNames: [String]
        let decimals: Int
        let symbol: String
        let asset: Asset?
    }

    // The table's rows: all by hand (CoinbaseExchangeChain+Overrides.swift). The importer generates none: Coinbase's
    // public products state increments, not decimals.
    static let rows: [Row] = overrideRows

    // Every wire name to its holding. A wire name in two rows traps (`uniqueKeysWithValues`) when the table is first
    // read.
    static let table: [String: CoinbaseHolding] = Dictionary(
        uniqueKeysWithValues: rows.flatMap { row in row.wireNames.map { ($0, row.holding) } }
    )

    private static func tokenInfo(of row: Row) -> SimpleTokenInfo<CoinbaseHolding> {
        let tokenName = row.asset.flatMap { asset in
            AssetRegistry.libraryDeclarations.first { $0.asset == asset }?.tokenName
        }
        return SimpleTokenInfo(contractAddress: row.holding, equivalentContracts: [], tokenName: tokenName ?? row.symbol,
                               symbol: row.symbol)
    }

    // MARK: The declarations

    /// Coinbase's holdings as instances of their classes, each declared beside its class's home: BTC in Bitcoin's,
    /// ETH in Ether's, USD in the dollar's
    package static let declarations: [AssetDeclaration] = rows.compactMap { row in
        guard let asset = row.asset,
              let library = AssetRegistry.libraryDeclarations.first(where: { $0.asset == asset }) else {
            return nil
        }
        let instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(row.holding), decimals: row.decimals, symbol: AssetSymbol(validating: row.symbol)
        )
        return try! AssetDeclaration(
            asset: library.asset, tokenName: library.tokenName, symbol: library.symbol, aggregatorId: library.aggregatorId,
            wholeUnit: .init(name: library.wholeUnit.name, symbol: library.wholeUnit.symbol,
                             fractionDigits: library.wholeUnit.fractionDigits),
            baseUnit: library.baseUnit.map { .init(name: $0.name, symbol: $0.symbol, fractionDigits: $0.fractionDigits) },
            between: library.between, displayUnit: library.displayUnit,
            instances: [library.instances[0], instance]
        )
    }

    /// The holdings on Coinbase that stand for a currency, one for one, with no conversion and no rate: Coinbase's dollar, the quote of its dollar products
    /// stand for the dollar, `iso4217:USD`
    package static let currencyDeclarations: [CurrencyDeclaration] = [
        CurrencyDeclaration(currency: ISO4217.usd.instance, holdings: [AssetInstance(CoinbaseHolding.usd)])
    ]

    /// Adds Coinbase's declarations and the holdings that stand for a currency to `registry` and registers the chain with `BlockChains`; twice is once
    ///
    /// Called at each Coinbase client's init, with the client's registry.
    ///
    /// - Throws: what `AssetRegistry.add(_:)` throws when `registry` states a Coinbase holding otherwise
    package static func declare(in registry: AssetRegistry) throws {
        try registry.add(declarations)
        try registry.add(currencyDeclarations)
        BlockChains.register(CoinbaseExchangeChain.default)
    }

    /// The declared instance of the holding Coinbase names `wireName`, checked against the precision Coinbase
    /// states for it, the decimal places of a product's increment in it (the units check, AR45); `nil` for a name the
    /// table lacks or a holding `registry` does not declare
    ///
    /// Coinbase states no decimals of its own, and an increment is a step, not the holding's count (design § 5.3):
    /// BTC-PERP-INTX steps BTC by "0.0001". So the check refuses only an increment finer than the declared decimals,
    /// which the holding could not count.
    ///
    /// - Throws: `AssetRegistryError.decimalsChanged` when Coinbase states an increment finer than the declared
    ///   decimals: the statement is stale, or Coinbase changed its precision (design § 2.1)
    package static func declaredInstance(wireName: String, decimals: Int, in registry: AssetRegistry) throws -> AssetInstance? {
        guard let holding = table[wireName] else {
            return nil
        }
        let instance = AssetInstance(holding)
        guard let declared = try? registry.decimals(of: instance) else {
            return nil
        }
        guard decimals <= declared else {
            throw AssetRegistryError.decimalsChanged(instance)
        }
        return instance
    }
}

// MARK: The scanner

/// Coinbase's scanner: an adapter over any C31 client of Coinbase, configured after it is made
///
/// Made without a client, as an aggregator is made without its key; until ``configure(client:)`` every read of an
/// account throws ``ExchangeClientError/unauthorized(text:)`` naming Coinbase, never a zero. ``loadTransactions(from:)``
/// needs no client.
///
/// ```swift
/// CoinbaseExchangeChain.default.scanner.configure(client: client)   // CoinbaseClient does this at its init
/// try await CoinbaseExchangeChain.default.scanner.getBalance(forAccount: account)
/// ```
public final class CoinbaseScanner: CryptoScanner, Sendable {
    public typealias Contract = CoinbaseHolding

    /// "Coinbase"
    public var userReadableName: String { "Coinbase" }

    /// Whether a client is configured; nothing to do with whether Coinbase answers
    public var isAvailable: Bool {
        reads.withLock { $0 != nil }
    }

    // Set from any concurrency domain and read from any, so it is held behind a `Mutex`.
    private let reads = Mutex<Reads?>(nil)

    private struct Reads: Sendable {
        let accountState: @Sendable (String) async throws -> ExchangeClientAccountState<CoinbaseMarketName>
        let transactions: @Sendable (String) async throws -> [CoinbaseTransaction]
    }

    /// A scanner with no client: every read of an account throws until ``configure(client:)``
    public init() {}

    /// Configures the scanner over `client`; a later call replaces the client
    public func configure<Client: ExchangeClient>(client: Client) where Client.MarketName == CoinbaseMarketName {
        let configured = Reads(
            accountState: { account in try await client.accountState(account: account) },
            transactions: { account in try await client.ledgerItems(account: account, since: nil).map(CoinbaseTransaction.init) }
        )
        reads.withLock { $0 = configured }
    }

    /// The account's balance as its client's account state states it, in Coinbase's USD
    ///
    /// - Throws: ``ExchangeClientError/unauthorized(text:)`` naming Coinbase when no client is configured; the client's
    ///   error; ``ExchangeClientError/refused(code:text:)`` when the balance is in no Coinbase holding
    public func getBalance(forAccount account: CoinbaseHolding) async throws -> Amount<CoinbaseHolding> {
        let balance = try await configured().accountState(account.address).balance
        return try Self.scanned(balance.baseUnits, in: balance.instance)
    }

    /// The holding's balance in the account: the account's balance when `contract` is the holding it is stated in,
    /// else the net units of the account's positions in `contract` (a buy's units added, a sell's subtracted), zero
    /// when it holds none
    ///
    /// - Throws: ``ExchangeClientError/unauthorized(text:)`` naming Coinbase when no client is configured; the client's
    ///   error; ``ExchangeClientError/refused(code:text:)`` when the balance is in no Coinbase holding
    public func getBalance(forToken contract: CoinbaseHolding, forAccount account: CoinbaseHolding) async throws -> Amount<CoinbaseHolding> {
        let state = try await configured().accountState(account.address)
        let instance = AssetInstance(contract)
        if state.balance.instance == instance {
            return try Self.scanned(state.balance.baseUnits, in: state.balance.instance)
        }
        let units = state.positions.filter { $0.units.instance == instance }.reduce(Int128(0)) { total, position in
            total + (position.side == .buy ? position.units.baseUnits : -position.units.baseUnits)
        }
        return .init(quantity: units, currency: contract)
    }

    /// The account's ledger as its client hands it up, each item a ``CoinbaseTransaction``
    ///
    /// - Throws: ``ExchangeClientError/unauthorized(text:)`` naming Coinbase when no client is configured; the client's
    ///   error; what ``CoinbaseTransaction/init(_:)`` throws for an item
    public func getTransactions(forAccount account: CoinbaseHolding) async throws -> [any CryptoTransaction] {
        try await configured().transactions(account.address)
    }

    /// The transactions a recorded list of ``CoinbaseTransaction``s holds, as they encode
    public func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        try JSONDecoder().decode([CoinbaseTransaction].self, from: data)
    }

    private func configured() throws -> Reads {
        guard let configured = reads.withLock({ $0 }) else {
            throw ExchangeClientError.unauthorized(text: "Coinbase's scanner has no client: configure(client:) was not called")
        }
        return configured
    }

    // An amount of the client's, its base units in a Coinbase holding, as the 2023 amount.
    fileprivate static func scanned(_ baseUnits: Int128, in instance: AssetInstance) throws -> Amount<CoinbaseHolding> {
        guard instance.chainId == EXCHANGE.Coinbase.chainId, let address = instance.address else {
            throw ExchangeClientError.refused(code: nil, text: "\(instance.id) is not a Coinbase holding")
        }
        return .init(quantity: baseUnits, currency: CoinbaseHolding(address: address))
    }
}

// MARK: The transaction

/// An item of Coinbase's ledger as the 2023 protocol's transaction: its time, its amount and its id
///
/// The id is the order's for a fill and the item's cursor for every other kind, each as its client writes it; the
/// kind is the ledger item's case ("fill", "funding", "deposit", "withdrawal", "internalMove").
public struct CoinbaseTransaction: CryptoTransaction, Sendable {
    public typealias Contract = CoinbaseHolding

    /// The item's id: the ledger's own, not a chain's transaction hash
    public let hash: String
    /// For a move between portfolios, the portfolio it left
    public let fromContract: CoinbaseHolding?
    /// For a move between portfolios, the portfolio it reached
    public let toContract: CoinbaseHolding?
    /// The item's amount in its Coinbase holding, in the holding's base units: a fill's units, a funding's,
    /// deposit's, withdrawal's or move's amount
    public let amount: Amount<CoinbaseHolding>
    /// When the item happened, as its client states it
    public let timeStamp: Date
    /// The order's id for a fill, the item's cursor for every other kind, as its client writes them
    public let transactionId: String
    /// `nil`: an exchange's ledger states no gas
    public var gas: Int? { nil }
    /// `nil`: an exchange's ledger states no gas
    public var gasPrice: Amount<CoinbaseHolding>? { nil }
    /// `nil`: an exchange's ledger states no gas
    public var gasUsed: Amount<CoinbaseHolding>? { nil }
    /// Always `true`: Coinbase's ledger lists only what happened
    public let successful: Bool
    /// `nil`: an exchange's ledger calls no function
    public var functionName: String? { nil }
    /// The ledger item's kind: "fill", "funding", "deposit", "withdrawal" or "internalMove"
    public let type: String?

    /// The transaction a ledger item is
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` when the item's amount is in no Coinbase holding; the
    ///   encoder's error when its id or cursor does not encode
    public init<OrderId: Encodable, Cursor: Encodable>(_ item: ExchangeClientLedgerItem<CoinbaseMarketName, OrderId, Cursor>) throws {
        let baseUnits: Int128
        let instance: AssetInstance
        let time: Date
        let id: String
        let kind: String
        var from: CoinbaseHolding?
        var to: CoinbaseHolding?
        switch item {
        case let .fill(_, _, units, _, _, order, _, fillTime, _, _):
            (baseUnits, instance, time, id, kind) = (units.baseUnits, units.instance, fillTime, try Self.text(of: order), "fill")
        case let .funding(_, funded, _, fundingTime, cursor):
            (baseUnits, instance, time, id, kind) = (funded.baseUnits, funded.instance, fundingTime, try Self.text(of: cursor), "funding")
        case let .deposit(deposited, depositTime, cursor):
            (baseUnits, instance, time, id, kind) = (deposited.baseUnits, deposited.instance, depositTime, try Self.text(of: cursor), "deposit")
        case let .withdrawal(withdrawn, withdrawalTime, cursor):
            (baseUnits, instance, time, id, kind) = (withdrawn.baseUnits, withdrawn.instance, withdrawalTime, try Self.text(of: cursor), "withdrawal")
        case let .internalMove(moved, source, destination, moveTime, cursor):
            (baseUnits, instance, time, id, kind) = (moved.baseUnits, moved.instance, moveTime, try Self.text(of: cursor), "internalMove")
            from = CoinbaseHolding(address: source)
            to = CoinbaseHolding(address: destination)
        }
        self.hash = id
        self.fromContract = from
        self.toContract = to
        self.amount = try CoinbaseScanner.scanned(baseUnits, in: instance)
        self.timeStamp = time
        self.transactionId = id
        self.successful = true
        self.type = kind
    }

    // A client's id or cursor as it writes itself: its JSON string's text, or its JSON where it is not a string.
    private static func text(of value: some Encodable) throws -> String {
        let json = try JSONEncoder().encode(value)
        return (try? JSONDecoder().decode(String.self, from: json)) ?? String(decoding: json, as: UTF8.self)
    }
}
