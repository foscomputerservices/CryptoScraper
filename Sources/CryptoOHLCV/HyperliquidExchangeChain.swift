// HyperliquidExchangeChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

// CryptoAsset's names are imported one by one, so `Amount` here is CryptoScraper's 2023 amount, the one its scanner
// protocol states; CryptoAsset's amount is never named in this file.
import enum CryptoAsset.EXCHANGE
import enum CryptoAsset.EIP155
import enum CryptoAsset.TRON
import enum CryptoAsset.AssetError
import enum CryptoAsset.AssetRegistryError
import class CryptoAsset.AssetRegistry
import struct CryptoAsset.Asset
import struct CryptoAsset.AssetDeclaration
import struct CryptoAsset.AssetInstance
import struct CryptoAsset.AssetSymbol
import CryptoExchange
import CryptoScraper
import FOSFoundation
import Foundation
import Synchronization

// Design § 1.3, the second placement of 2026-10-07: Hyperliquid as a chain of the 2023 protocols, declared here beside
// Hyperliquid's market name and errors, so both of Hyperliquid's clients (its candle client here, its exchange client
// in CryptoHyperliquid) work in the same holding constants. This file is the only place Hyperliquid's strings are
// written: its wire names, in one table, and its holdings' keys, decimals and symbols, as constants.

/// Hyperliquid as a chain: its holdings are its contracts, its client is its scanner
///
/// ```swift
/// HyperliquidExchangeChain.default.id                            // "exchange:hyperliquid"
/// try HyperliquidExchangeChain.default.contract(for: "BTC")      // HyperliquidHolding.btc
/// ```
public final class HyperliquidExchangeChain: CryptoChain, Sendable {
    /// In the library's own `exchange` namespace: no CAIP-2 namespace exists for exchanges
    public let id: String = EXCHANGE.Hyperliquid.chainId

    /// "Hyperliquid"
    public let userReadableName: String = "Hyperliquid"

    /// Hyperliquid's USDC, the holding an account's value is stated in
    public let mainContract: HyperliquidHolding!

    /// Never `nil` (the owner's word, 2026-10-07): made without a client, configured with one through
    /// ``HyperliquidScanner/configure(client:)``
    public let scanner: HyperliquidScanner

    /// The one Hyperliquid chain
    public static let `default`: HyperliquidExchangeChain = .init()

    // Made, the chain is registered with `BlockChains`, so `contract(of:)` answers for its holdings (design § 1.3)
    private init() {
        self.mainContract = .usdc
        self.scanner = HyperliquidScanner()
        BlockChains.register(self)
    }

    /// The holding Hyperliquid names `address` on the wire ("BTC", "kPEPE"), case included
    ///
    /// - Throws: ``AssetError/malformedIdentity(_:)`` for a name the table lacks: a finding, never a holding minted
    ///   from the string
    public func contract(for address: String) throws -> HyperliquidHolding {
        guard let holding = Self.table[address] else {
            throw AssetError.malformedIdentity(address)
        }
        return holding
    }

    /// Every holding in the table, each with its symbol and its asset's token name; a holding with no declared class
    /// (kPEPE) is listed too, its symbol standing for its name
    public var chainTokenInfos: Set<SimpleTokenInfo<HyperliquidHolding>> {
        Set(Self.rows.map(Self.tokenInfo(of:)))
    }

    /// The table's holding whose key is `address`, with its symbol and its asset's token name (its symbol where no
    /// class is declared); `nil` for any other address
    public func tokenInfo(for address: String) -> SimpleTokenInfo<HyperliquidHolding>? {
        Self.rows.first { $0.holding.address == address }.map(Self.tokenInfo(of:))
    }

    /// Nothing to load: Hyperliquid's holdings are declared constants, never read from an aggregator
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {}
}

/// A holding of an asset on Hyperliquid, or an account on it, by the library's key for it
///
/// The constants (``btc``, ``eth``, ``usdc``, ``sol``, ``kPEPE``, ``bnb``, ``pol``, ``trx``) are what every call works in; Hyperliquid's own
/// names for them reach them only through ``HyperliquidExchangeChain/contract(for:)``. A key is Hyperliquid's name as
/// it spells it, case included, since its wire names are its only names (design § 1.3).
///
/// ```swift
/// AssetInstance(HyperliquidHolding.btc).id      // "exchange:hyperliquid:BTC"
/// HyperliquidHolding.btc.wireName               // "BTC", the coin Hyperliquid accepts in a request
/// ```
public struct HyperliquidHolding: CryptoContract, Codable, Stubbable, Sendable {
    /// One unit, the base unit, exponent 0: one ladder per exchange cannot hold every holding's decimals, which the
    /// statement holds (design § 1.3); a holding is never rendered through `CurrencyFormatter`
    public enum Units: CurrencyUnits {
        case base

        public static var chainBaseUnits: Self { .base }
        public static var defaultDisplayUnits: Self { .base }
    }

    public typealias Chain = HyperliquidExchangeChain

    /// The library's key for the holding ("BTC"), declared once, or an account's name or address
    public let address: String

    /// A holding or an account by the library's key for it, never by a name read from Hyperliquid's wire: those reach
    /// a holding through ``HyperliquidExchangeChain/contract(for:)``
    public init(address: String) {
        self.address = address
    }

    /// The one name Hyperliquid accepts for it on the wire, from the table; an account's name is its own
    public var wireName: String {
        HyperliquidExchangeChain.rows.first { $0.holding == self }?.wireNames.first ?? address
    }
}

public extension HyperliquidHolding {
    /// Bitcoin's perpetual on Hyperliquid, "BTC", at 5 decimals, its size decimals and so its lot, in `Asset.btc`
    static let btc = HyperliquidHolding(address: "BTC")
    /// Ether's perpetual on Hyperliquid, "ETH", at 4 decimals, in `Asset.eth`
    static let eth = HyperliquidHolding(address: "ETH")
    /// Hyperliquid's USDC, its unit of account, at 6 decimals, in `Asset.usdc`
    static let usdc = HyperliquidHolding(address: "USDC")
    /// Solana's coin's perpetual on Hyperliquid, "SOL", at 2 decimals, in Solana's class (`SOLANA.Solana.sol`'s asset)
    static let sol = HyperliquidHolding(address: "SOL")
    /// A thousand PEPE on Hyperliquid, "kPEPE", at 0 decimals; undeclared until a scale is designed (design § 7.2)
    static let kPEPE = HyperliquidHolding(address: "kPEPE")
    /// BNB's perpetual on Hyperliquid, "BNB", at 3 decimals, in BNB Smart Chain's coin's class
    static let bnb = HyperliquidHolding(address: "BNB")
    /// POL's perpetual on Hyperliquid, "POL", at 0 decimals, in Polygon's coin's class
    static let pol = HyperliquidHolding(address: "POL")
    /// TRX's perpetual on Hyperliquid, "TRX", at 0 decimals, in Tron's coin's class
    static let trx = HyperliquidHolding(address: "TRX")
}

public extension HyperliquidHolding {
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

public extension HyperliquidHolding {
    /// An account on the reserved fake: no exchange names a holding FRED
    static func stub() -> Self { .stub(address: "FRED") }

    /// A holding or an account by any key, FRED by default
    static func stub(address: String = "FRED") -> Self {
        .init(address: address)
    }
}

public extension HyperliquidHolding.Units {
    /// 1: the base unit alone, exponent 0
    var divisorFromBase: UInt128 { 1 }
    /// None: a holding is rendered by its declared units (C10), never by this ladder
    var displayIdentifier: String { "" }
    /// 0: base units are whole
    var displayFractionDigits: Int { 0 }
}

// MARK: The table

extension HyperliquidExchangeChain {
    // One row per holding: its constant, Hyperliquid's name for it, and its decimals and symbol: a coin's as
    // Hyperliquid's recorded `meta` answer of 2026-10-06 states its `szDecimals`, USDC's as the design states it (§ 2.1;
    // no `meta` lists USDC, and the client's sub-account transfer counts it in millionths); the asset it is an instance
    // of, or nil where no class is declared for it yet. The wire is checked against these, never the source of them.
    struct Row: Sendable {
        let holding: HyperliquidHolding
        let wireNames: [String]
        let decimals: Int
        let symbol: String
        let asset: Asset?
    }

    // The table's rows: all by hand (HyperliquidExchangeChain+Overrides.swift). The importer generates none:
    // CoinGecko's tickers read answers no ticker for Hyperliquid (recorded 2026-10-07), and no meta lists USDC.
    static let rows: [Row] = overrideRows

    // Every wire name to its holding. A wire name in two rows traps (`uniqueKeysWithValues`) when the table is first
    // read.
    static let table: [String: HyperliquidHolding] = Dictionary(
        uniqueKeysWithValues: rows.flatMap { row in row.wireNames.map { ($0, row.holding) } }
    )

    private static func tokenInfo(of row: Row) -> SimpleTokenInfo<HyperliquidHolding> {
        let tokenName = row.asset.flatMap { asset in
            AssetRegistry.libraryDeclarations.first { $0.asset == asset }?.tokenName
        }
        return SimpleTokenInfo(contractAddress: row.holding, equivalentContracts: [], tokenName: tokenName ?? row.symbol,
                               symbol: row.symbol)
    }

    // MARK: The declarations

    /// Hyperliquid's holdings as instances of their classes, each declared beside its class's home: BTC in Bitcoin's,
    /// ETH in Ether's, USDC in USD Coin's, BNB, POL and TRX in their chains' coins'; a holding with no declared class
    /// is left out
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

    /// Adds Hyperliquid's declarations to `registry` and registers the chain with `BlockChains`; twice is once
    ///
    /// Called at each Hyperliquid client's init, with the client's registry.
    ///
    /// - Throws: what `AssetRegistry.add(_:)` throws when `registry` states a Hyperliquid holding otherwise
    package static func declare(in registry: AssetRegistry) throws {
        try registry.add(declarations)
        BlockChains.register(HyperliquidExchangeChain.default)
    }

    /// The declared instance of the holding Hyperliquid names `wireName`, checked against the decimals Hyperliquid
    /// states for it, a coin's `szDecimals` (the units check, AR45); `nil` for a name the table lacks or a holding
    /// `registry` does not declare
    ///
    /// - Throws: `AssetRegistryError.decimalsChanged` when Hyperliquid states decimals other than the declared ones:
    ///   the statement is stale, or Hyperliquid changed its precision (design § 2.1)
    package static func declaredInstance(wireName: String, decimals: Int, in registry: AssetRegistry) throws -> AssetInstance? {
        guard let holding = table[wireName] else {
            return nil
        }
        let instance = AssetInstance(holding)
        guard let declared = try? registry.decimals(of: instance) else {
            return nil
        }
        guard declared == decimals else {
            throw AssetRegistryError.decimalsChanged(instance)
        }
        return instance
    }
}

// MARK: The scanner

/// Hyperliquid's scanner: an adapter over any C31 client of Hyperliquid, configured after it is made
///
/// Made without a client, as an aggregator is made without its key; until ``configure(client:)`` every read of an
/// account throws ``ExchangeClientError/unauthorized(text:)`` naming Hyperliquid, never a zero. ``loadTransactions(from:)``
/// needs no client.
///
/// ```swift
/// HyperliquidExchangeChain.default.scanner.configure(client: client)   // HyperliquidClient does this at its init
/// try await HyperliquidExchangeChain.default.scanner.getBalance(forAccount: account)
/// ```
public final class HyperliquidScanner: CryptoScanner, Sendable {
    public typealias Contract = HyperliquidHolding

    /// "Hyperliquid"
    public var userReadableName: String { "Hyperliquid" }

    /// Whether a client is configured; nothing to do with whether Hyperliquid answers
    public var isAvailable: Bool {
        reads.withLock { $0 != nil }
    }

    // Set from any concurrency domain and read from any, so it is held behind a `Mutex`.
    private let reads = Mutex<Reads?>(nil)

    private struct Reads: Sendable {
        let accountState: @Sendable (String) async throws -> ExchangeClientAccountState<HyperliquidMarketName>
        let transactions: @Sendable (String) async throws -> [HyperliquidTransaction]
    }

    /// A scanner with no client: every read of an account throws until ``configure(client:)``
    public init() {}

    /// Configures the scanner over `client`; a later call replaces the client
    public func configure<Client: ExchangeClient>(client: Client) where Client.MarketName == HyperliquidMarketName {
        let configured = Reads(
            accountState: { account in try await client.accountState(account: account) },
            transactions: { account in try await client.ledgerItems(account: account, since: nil).map(HyperliquidTransaction.init) }
        )
        reads.withLock { $0 = configured }
    }

    /// The account's balance as its client's account state states it, in Hyperliquid's USDC
    ///
    /// - Throws: ``ExchangeClientError/unauthorized(text:)`` naming Hyperliquid when no client is configured; the client's
    ///   error; ``ExchangeClientError/refused(code:text:)`` when the balance is in no Hyperliquid holding
    public func getBalance(forAccount account: HyperliquidHolding) async throws -> Amount<HyperliquidHolding> {
        let balance = try await configured().accountState(account.address).balance
        return try Self.scanned(balance.baseUnits, in: balance.instance)
    }

    /// The holding's balance in the account: the account's balance when `contract` is the holding it is stated in,
    /// else the net units of the account's positions in `contract` (a buy's units added, a sell's subtracted), zero
    /// when it holds none
    ///
    /// - Throws: ``ExchangeClientError/unauthorized(text:)`` naming Hyperliquid when no client is configured; the client's
    ///   error; ``ExchangeClientError/refused(code:text:)`` when the balance is in no Hyperliquid holding
    public func getBalance(forToken contract: HyperliquidHolding, forAccount account: HyperliquidHolding) async throws -> Amount<HyperliquidHolding> {
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

    /// The account's ledger as its client hands it up, each item a ``HyperliquidTransaction``
    ///
    /// - Throws: ``ExchangeClientError/unauthorized(text:)`` naming Hyperliquid when no client is configured; the client's
    ///   error; what ``HyperliquidTransaction/init(_:)`` throws for an item
    public func getTransactions(forAccount account: HyperliquidHolding) async throws -> [any CryptoTransaction] {
        try await configured().transactions(account.address)
    }

    /// The transactions a recorded list of ``HyperliquidTransaction``s holds, as they encode
    public func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        try JSONDecoder().decode([HyperliquidTransaction].self, from: data)
    }

    private func configured() throws -> Reads {
        guard let configured = reads.withLock({ $0 }) else {
            throw ExchangeClientError.unauthorized(text: "Hyperliquid's scanner has no client: configure(client:) was not called")
        }
        return configured
    }

    // An amount of the client's, its base units in a Hyperliquid holding, as the 2023 amount.
    fileprivate static func scanned(_ baseUnits: Int128, in instance: AssetInstance) throws -> Amount<HyperliquidHolding> {
        guard instance.chainId == EXCHANGE.Hyperliquid.chainId, let address = instance.address else {
            throw ExchangeClientError.refused(code: nil, text: "\(instance.id) is not a Hyperliquid holding")
        }
        return .init(quantity: baseUnits, currency: HyperliquidHolding(address: address))
    }
}

// MARK: The transaction

/// An item of Hyperliquid's ledger as the 2023 protocol's transaction: its time, its amount and its id
///
/// The id is the order's for a fill and the item's cursor for every other kind, each as its client writes it; the
/// kind is the ledger item's case ("fill", "funding", "deposit", "withdrawal", "internalMove").
public struct HyperliquidTransaction: CryptoTransaction, Sendable {
    public typealias Contract = HyperliquidHolding

    /// The item's id: the ledger's own, not a chain's transaction hash
    public let hash: String
    /// For a move between accounts, the account it left
    public let fromContract: HyperliquidHolding?
    /// For a move between accounts, the account it reached
    public let toContract: HyperliquidHolding?
    /// The item's amount in its Hyperliquid holding, in the holding's base units: a fill's units, a funding's,
    /// deposit's, withdrawal's or move's USDC
    public let amount: Amount<HyperliquidHolding>
    /// When the item happened, as its client states it
    public let timeStamp: Date
    /// The order's id for a fill, the item's cursor for every other kind, as its client writes them
    public let transactionId: String
    /// `nil`: an exchange's ledger states no gas
    public var gas: Int? { nil }
    /// `nil`: an exchange's ledger states no gas
    public var gasPrice: Amount<HyperliquidHolding>? { nil }
    /// `nil`: an exchange's ledger states no gas
    public var gasUsed: Amount<HyperliquidHolding>? { nil }
    /// Always `true`: Hyperliquid's ledger lists only what happened
    public let successful: Bool
    /// `nil`: an exchange's ledger calls no function
    public var functionName: String? { nil }
    /// The ledger item's kind: "fill", "funding", "deposit", "withdrawal" or "internalMove"
    public let type: String?

    /// The transaction a ledger item is
    ///
    /// - Throws: ``ExchangeClientError/refused(code:text:)`` when the item's amount is in no Hyperliquid holding; the
    ///   encoder's error when its id or cursor does not encode
    public init<OrderId: Encodable, Cursor: Encodable>(_ item: ExchangeClientLedgerItem<HyperliquidMarketName, OrderId, Cursor>) throws {
        let baseUnits: Int128
        let instance: AssetInstance
        let time: Date
        let id: String
        let kind: String
        var from: HyperliquidHolding?
        var to: HyperliquidHolding?
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
            from = HyperliquidHolding(address: source)
            to = HyperliquidHolding(address: destination)
        }
        self.hash = id
        self.fromContract = from
        self.toContract = to
        self.amount = try HyperliquidScanner.scanned(baseUnits, in: instance)
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
