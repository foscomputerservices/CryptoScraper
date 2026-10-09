// BinanceExchangeChain.swift
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
import CryptoScraper
import FOSFoundation
import Foundation

// Design § 1.3, the second placement of 2026-10-07: Binance as a chain of the 2023 protocols, declared here beside
// Binance's market name and errors and its candle client, the one Binance client of this package. This file is the
// only place Binance's strings are written: its wire names, in one table, and its holdings' keys, decimals and
// symbols, as constants.

/// Binance as a chain: its holdings are its contracts; it has no account client, so its scanner is ``NilScanner``
///
/// ```swift
/// BinanceExchangeChain.default.id                             // "exchange:binance"
/// try BinanceExchangeChain.default.contract(for: "USDT")      // BinanceHolding.usdt
/// ```
public final class BinanceExchangeChain: CryptoChain, Sendable {
    /// In the library's own `exchange` namespace: no CAIP-2 namespace exists for exchanges
    public let id: String = EXCHANGE.Binance.chainId

    /// "Binance"
    public let userReadableName: String = "Binance"

    /// Binance's USDT, the holding an account's value is stated in
    public let mainContract: BinanceHolding!

    /// Never `nil` (the owner's word, 2026-10-07): Binance has no account client in this package, so its chain
    /// specifies the scanner that answers zero and nothing
    public let scanner: NilScanner<BinanceHolding>

    /// The one Binance chain
    public static let `default`: BinanceExchangeChain = .init()

    // Made, the chain is registered with `BlockChains`, so `contract(of:)` answers for its holdings (design § 1.3)
    private init() {
        self.mainContract = .usdt
        self.scanner = NilScanner()
        BlockChains.register(self)
    }

    /// The holding Binance names `address` on the wire ("BTC", "USDT")
    ///
    /// - Throws: ``AssetError/malformedIdentity(_:)`` for a name the table lacks: a finding, never a holding minted
    ///   from the string
    public func contract(for address: String) throws -> BinanceHolding {
        guard let holding = Self.table[address] else {
            throw AssetError.malformedIdentity(address)
        }
        return holding
    }

    /// The declared holdings, each with its symbol and its asset's name
    public var chainTokenInfos: Set<SimpleTokenInfo<BinanceHolding>> {
        Set(Self.rows.map(Self.tokenInfo(of:)))
    }

    /// The declared holding whose key is `address`, with its symbol and its asset's name; `nil` for any other address
    public func tokenInfo(for address: String) -> SimpleTokenInfo<BinanceHolding>? {
        Self.rows.first { $0.holding.address == address }.map(Self.tokenInfo(of:))
    }

    /// Nothing to load: Binance's holdings are declared constants, never read from an aggregator
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {}
}

/// A holding of an asset on Binance, or an account on it, by the library's key for it
///
/// The constants (``btc``, ``usdt``) are what every call works in; Binance's own names for them reach them only
/// through ``BinanceExchangeChain/contract(for:)``.
///
/// ```swift
/// AssetInstance(BinanceHolding.usdt).id      // "exchange:binance:USDT"
/// BinanceHolding.usdt.wireName               // "USDT", the asset Binance names in its exchange information
/// ```
public struct BinanceHolding: CryptoContract, Codable, Stubbable, Sendable {
    /// One unit, the base unit, exponent 0: one ladder per exchange cannot hold every holding's decimals, which the
    /// statement holds (design § 1.3); a holding is never rendered through `CurrencyFormatter`
    public enum Units: CurrencyUnits {
        case base

        public static var chainBaseUnits: Self { .base }
        public static var defaultDisplayUnits: Self { .base }
    }

    public typealias Chain = BinanceExchangeChain

    /// The library's key for the holding ("USDT"), declared once, or an account's name
    public let address: String

    /// A holding or an account by the library's key for it, never by a name read from Binance's wire: those reach a
    /// holding through ``BinanceExchangeChain/contract(for:)``
    public init(address: String) {
        self.address = address
    }

    /// The one name Binance gives it on the wire, from the table; an account's name is its own
    public var wireName: String {
        BinanceExchangeChain.rows.first { $0.holding == self }?.wireNames.first ?? address
    }
}

public extension BinanceHolding {
    /// Bitcoin on Binance, "BTC", at 8 decimals, in `Asset.btc`
    static let btc = BinanceHolding(address: "BTC")
    /// Tether on Binance, "USDT", at 8 decimals, in `Asset.usdt` beside Ethereum's tether at 6
    static let usdt = BinanceHolding(address: "USDT")
    /// USD Coin on Binance, "USDC", at 8 decimals, in `Asset.usdc` beside Ethereum's USDC at 6
    static let usdc = BinanceHolding(address: "USDC")
}

public extension BinanceHolding {
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

public extension BinanceHolding {
    /// An account on the reserved fake: no exchange names a holding FRED
    static func stub() -> Self { .stub(address: "FRED") }

    /// A holding or an account by any key, FRED by default
    static func stub(address: String = "FRED") -> Self {
        .init(address: address)
    }
}

public extension BinanceHolding.Units {
    /// 1: the base unit alone, exponent 0
    var divisorFromBase: UInt128 { 1 }
    /// None: a holding is rendered by its declared units (C10), never by this ladder
    var displayIdentifier: String { "" }
    /// 0: base units are whole
    var displayFractionDigits: Int { 0 }
}

// MARK: The table

extension BinanceExchangeChain {
    // One row per holding: its constant, Binance's name for it, and its decimals and symbol as Binance's recorded
    // exchange information of 2026-10-04 states them (BTCUSDT: `baseAssetPrecision` 8, `quotePrecision` and
    // `quoteAssetPrecision` 8); the asset it is an instance of. Only what the recording states is declared. The wire is
    // checked against these, never the source of them.
    struct Row: Sendable {
        let holding: BinanceHolding
        let wireNames: [String]
        let decimals: Int
        let symbol: String
        let asset: Asset?
    }

    // The table's rows: the ones Scripts/import-assets.swift generates from Binance's exchange information and
    // CoinGecko's tickers (BinanceExchangeChain+Imported.swift), and the ones the sources cannot state, by hand
    // (BinanceExchangeChain+Overrides.swift). A test refuses a wire name in both.
    static let rows: [Row] = importedRows + overrideRows

    // Every wire name to its holding. A wire name in two rows traps (`uniqueKeysWithValues`) when the table is first
    // read.
    static let table: [String: BinanceHolding] = Dictionary(
        uniqueKeysWithValues: rows.flatMap { row in row.wireNames.map { ($0, row.holding) } }
    )

    private static func tokenInfo(of row: Row) -> SimpleTokenInfo<BinanceHolding> {
        let tokenName = row.asset.flatMap { asset in
            AssetRegistry.libraryDeclarations.first { $0.asset == asset }?.tokenName
        }
        return SimpleTokenInfo(contractAddress: row.holding, equivalentContracts: [], tokenName: tokenName ?? row.symbol,
                               symbol: row.symbol)
    }

    // MARK: The declarations

    /// Binance's holdings as instances of their classes, each declared beside its class's home: BTC in Bitcoin's,
    /// USDT in Tether's; a holding with no declared class is left out
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

    /// The holdings on Binance that stand for a currency, one for one, with no conversion and no rate: Binance's tether and its USDC
    /// stand for the dollar, `iso4217:USD`
    package static let currencyDeclarations: [CurrencyDeclaration] = [
        CurrencyDeclaration(currency: ISO4217.usd.instance, holdings: [AssetInstance(BinanceHolding.usdt), AssetInstance(BinanceHolding.usdc)])
    ]

    /// Adds Binance's declarations and the holdings that stand for a currency to `registry` and registers the chain with `BlockChains`; twice is once
    ///
    /// Called at the candle client's init and at a market's, with their registry.
    ///
    /// - Throws: what `AssetRegistry.add(_:)` throws when `registry` states a Binance holding otherwise
    package static func declare(in registry: AssetRegistry) throws {
        try registry.add(declarations)
        try registry.add(currencyDeclarations)
        BlockChains.register(BinanceExchangeChain.default)
    }

    /// The declared instance of the holding Binance names `wireName`, checked against the precision Binance states
    /// for it in its exchange information (the units check, AR45); `nil` for a name the table lacks or a holding
    /// `registry` does not declare
    ///
    /// - Throws: `AssetRegistryError.decimalsChanged` when Binance states another precision than the declared
    ///   decimals: the statement is stale, or Binance changed its precision (design § 2.1)
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
