// AssetRegistry.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// The statement of every asset the process knows: its instances on chains and exchanges, their decimals and
/// symbols, and the class each belongs to
///
/// Holds the library's own declarations from the start. A service adds the rows built from CryptoScraper's chain
/// tables once at start, and replaces them when it refreshes. A miss is an error, never a default.
///
/// ```swift
/// let registry = try AssetRegistry(AssetRegistry.libraryDeclarations + exchangeDeclarations)
/// try registry.asset(of: binanceUSDT) == .usdt                     // true
/// try registry.decimals(of: binanceUSDT)                           // 8
/// ```
public final class AssetRegistry: @unchecked Sendable {
    // Every read and write of the statement goes through `lock`; the statement is never handed out by reference.
    // R1 keeps this library on Foundation and FOSFoundation, so the lock is Foundation's.
    private let lock = NSLock()
    private var statement: Statement

    /// The registry every lookup reads when none is passed, holding the library's declarations from the start: the
    /// hand-written ones and every generated one (design § 2.7); each exchange chain adds its own to its client's
    /// registry, this one by default, when the client is made
    public static let shared: AssetRegistry = try! AssetRegistry(libraryDeclarations)

    /// The declarations this library makes of its own: by hand, what the importer never generates (the dollar and the
    /// coins of CryptoScraper's chains, Optimism's and Base's ether instances of Ethereum's); then every declaration the
    /// importer generated, ``Assets/all``, USD Coin's and Tether's among them
    public static let libraryDeclarations: [AssetDeclaration] = [
        try! AssetDeclaration(
            asset: .usd, tokenName: "US Dollar", symbol: ISO4217.usd.symbol,
            wholeUnit: .init(name: "dollar", symbol: "$", fractionDigits: 2),
            baseUnit: .init(name: "cent", symbol: "¢"),
            instances: [ISO4217.usd]
        ),
        try! AssetDeclaration(
            asset: .btc, tokenName: "Bitcoin", symbol: BIP122.Bitcoin.btc.symbol,
            wholeUnit: .init(name: "bitcoin", symbol: "₿", fractionDigits: 8),
            baseUnit: .init(name: "satoshi"),
            instances: [BIP122.Bitcoin.btc]
        ),
        try! AssetDeclaration(
            asset: .eth, tokenName: "Ethereum", symbol: EIP155.Ethereum.eth.symbol,
            wholeUnit: .init(name: "ether", symbol: "Ξ"),
            baseUnit: .init(name: "wei"),
            between: [.init(name: "gwei", exponent: 9)],
            instances: [EIP155.Ethereum.eth, EIP155.Optimism.eth, EIP155.Base.eth]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: EIP155.BinanceSmartChain.bnb.instance.id), tokenName: "BNB",
            symbol: EIP155.BinanceSmartChain.bnb.symbol,
            instances: [EIP155.BinanceSmartChain.bnb]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: EIP155.Polygon.pol.instance.id), tokenName: "POL",
            symbol: EIP155.Polygon.pol.symbol,
            instances: [EIP155.Polygon.pol]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: EIP155.Fantom.ftm.instance.id), tokenName: "Fantom",
            symbol: EIP155.Fantom.ftm.symbol,
            instances: [EIP155.Fantom.ftm]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: TRON.Tron.trx.instance.id), tokenName: "TRON",
            symbol: TRON.Tron.trx.symbol,
            instances: [TRON.Tron.trx]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: EIP155.Avalanche.avax.instance.id), tokenName: "Avalanche",
            symbol: EIP155.Avalanche.avax.symbol,
            instances: [EIP155.Avalanche.avax]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: EIP155.EthereumClassic.etc.instance.id), tokenName: "Ethereum Classic",
            symbol: EIP155.EthereumClassic.etc.symbol,
            instances: [EIP155.EthereumClassic.etc]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: EIP155.Celo.celo.instance.id), tokenName: "Celo",
            symbol: EIP155.Celo.celo.symbol,
            instances: [EIP155.Celo.celo]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: EIP155.Theta.tfuel.instance.id), tokenName: "Theta Fuel",
            symbol: EIP155.Theta.tfuel.symbol,
            instances: [EIP155.Theta.tfuel]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: EIP155.COTI.coti.instance.id), tokenName: "COTI",
            symbol: EIP155.COTI.coti.symbol,
            instances: [EIP155.COTI.coti]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: SOLANA.Solana.sol.instance.id), tokenName: "Solana",
            symbol: SOLANA.Solana.sol.symbol,
            instances: [SOLANA.Solana.sol]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: XRPL.XRPLedger.xrp.instance.id), tokenName: "XRP",
            symbol: XRPL.XRPLedger.xrp.symbol,
            instances: [XRPL.XRPLedger.xrp]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: STELLAR.Stellar.xlm.instance.id), tokenName: "Stellar",
            symbol: STELLAR.Stellar.xlm.symbol,
            instances: [STELLAR.Stellar.xlm]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: TEZOS.Tezos.xtz.instance.id), tokenName: "Tezos",
            symbol: TEZOS.Tezos.xtz.symbol,
            instances: [TEZOS.Tezos.xtz]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: ALGORAND.Algorand.algo.instance.id), tokenName: "Algorand",
            symbol: ALGORAND.Algorand.algo.symbol,
            instances: [ALGORAND.Algorand.algo]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: HEDERA.Hedera.hbar.instance.id), tokenName: "Hedera",
            symbol: HEDERA.Hedera.hbar.symbol,
            instances: [HEDERA.Hedera.hbar]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: NEO.Neo.neo.instance.id), tokenName: "Neo",
            symbol: NEO.Neo.neo.symbol,
            instances: [NEO.Neo.neo]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: NEO.Neo.gas.instance.id), tokenName: "Gas",
            symbol: NEO.Neo.gas.symbol,
            instances: [NEO.Neo.gas]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: FIL.Filecoin.fil.instance.id), tokenName: "Filecoin",
            symbol: FIL.Filecoin.fil.symbol,
            instances: [FIL.Filecoin.fil]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: MVX.MultiversX.egld.instance.id), tokenName: "MultiversX",
            symbol: MVX.MultiversX.egld.symbol,
            instances: [MVX.MultiversX.egld]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: STACKS.Stacks.stx.instance.id), tokenName: "Stacks",
            symbol: STACKS.Stacks.stx.symbol,
            instances: [STACKS.Stacks.stx]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: IOTA.Iota.iota.instance.id), tokenName: "IOTA",
            symbol: IOTA.Iota.iota.symbol,
            instances: [IOTA.Iota.iota]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: VECHAIN.VeChain.vet.instance.id), tokenName: "VeChain",
            symbol: VECHAIN.VeChain.vet.symbol,
            instances: [VECHAIN.VeChain.vet]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: VECHAIN.VeChain.vtho.instance.id), tokenName: "VeThor Token",
            symbol: VECHAIN.VeChain.vtho.symbol,
            instances: [VECHAIN.VeChain.vtho]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: ARWEAVE.Arweave.ar.instance.id), tokenName: "Arweave",
            symbol: ARWEAVE.Arweave.ar.symbol,
            instances: [ARWEAVE.Arweave.ar]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: MINA.Mina.mina.instance.id), tokenName: "Mina",
            symbol: MINA.Mina.mina.symbol,
            instances: [MINA.Mina.mina]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: CONFLUX.Conflux.cfx.instance.id), tokenName: "Conflux",
            symbol: CONFLUX.Conflux.cfx.symbol,
            instances: [CONFLUX.Conflux.cfx]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: FLOW.Flow.flow.instance.id), tokenName: "Flow",
            symbol: FLOW.Flow.flow.symbol,
            instances: [FLOW.Flow.flow]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: BIP122.Litecoin.ltc.instance.id), tokenName: "Litecoin",
            symbol: BIP122.Litecoin.ltc.symbol,
            instances: [BIP122.Litecoin.ltc]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: BIP122.Dogecoin.doge.instance.id), tokenName: "Dogecoin",
            symbol: BIP122.Dogecoin.doge.symbol,
            instances: [BIP122.Dogecoin.doge]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: BIP122.BitcoinCash.bch.instance.id), tokenName: "Bitcoin Cash",
            symbol: BIP122.BitcoinCash.bch.symbol,
            instances: [BIP122.BitcoinCash.bch]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: BIP122.Dash.dash.instance.id), tokenName: "Dash",
            symbol: BIP122.Dash.dash.symbol,
            instances: [BIP122.Dash.dash]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: BIP122.DigiByte.dgb.instance.id), tokenName: "DigiByte",
            symbol: BIP122.DigiByte.dgb.symbol,
            instances: [BIP122.DigiByte.dgb]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: BIP122.Ravencoin.rvn.instance.id), tokenName: "Ravencoin",
            symbol: BIP122.Ravencoin.rvn.symbol,
            instances: [BIP122.Ravencoin.rvn]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: BIP122.Zcash.zec.instance.id), tokenName: "Zcash",
            symbol: BIP122.Zcash.zec.symbol,
            instances: [BIP122.Zcash.zec]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: BIP122.Verge.xvg.instance.id), tokenName: "Verge",
            symbol: BIP122.Verge.xvg.symbol,
            instances: [BIP122.Verge.xvg]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: BIP122.Qtum.qtum.instance.id), tokenName: "Qtum",
            symbol: BIP122.Qtum.qtum.symbol,
            instances: [BIP122.Qtum.qtum]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: BIP122.ECash.xec.instance.id), tokenName: "eCash",
            symbol: BIP122.ECash.xec.symbol,
            instances: [BIP122.ECash.xec]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: COSMOS.CosmosHub.atom.instance.id), tokenName: "Cosmos",
            symbol: COSMOS.CosmosHub.atom.symbol,
            instances: [COSMOS.CosmosHub.atom]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: COSMOS.THORChain.rune.instance.id), tokenName: "THORChain",
            symbol: COSMOS.THORChain.rune.symbol,
            instances: [COSMOS.THORChain.rune]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: COSMOS.Terra.luna.instance.id), tokenName: "Terra",
            symbol: COSMOS.Terra.luna.symbol,
            instances: [COSMOS.Terra.luna]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: COSMOS.FetchAI.fet.instance.id), tokenName: "Artificial Superintelligence Alliance",
            symbol: COSMOS.FetchAI.fet.symbol,
            instances: [COSMOS.FetchAI.fet]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: POLKADOT.Polkadot.dot.instance.id), tokenName: "Polkadot",
            symbol: POLKADOT.Polkadot.dot.symbol,
            instances: [POLKADOT.Polkadot.dot]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: POLKADOT.Kusama.ksm.instance.id), tokenName: "Kusama",
            symbol: POLKADOT.Kusama.ksm.symbol,
            instances: [POLKADOT.Kusama.ksm]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: NEAR.Near.near.instance.id), tokenName: "NEAR Protocol",
            symbol: NEAR.Near.near.symbol,
            instances: [NEAR.Near.near]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: CIP34.Cardano.ada.instance.id), tokenName: "Cardano",
            symbol: CIP34.Cardano.ada.symbol,
            instances: [CIP34.Cardano.ada]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: ICP.InternetComputer.icp.instance.id), tokenName: "Internet Computer",
            symbol: ICP.InternetComputer.icp.symbol,
            instances: [ICP.InternetComputer.icp]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: ONT.Ontology.ont.instance.id), tokenName: "Ontology",
            symbol: ONT.Ontology.ont.symbol,
            instances: [ONT.Ontology.ont]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: ONT.Ontology.ong.instance.id), tokenName: "Ontology Gas",
            symbol: ONT.Ontology.ong.symbol,
            instances: [ONT.Ontology.ong]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: ZIL.Zilliqa.zil.instance.id), tokenName: "Zilliqa",
            symbol: ZIL.Zilliqa.zil.symbol,
            instances: [ZIL.Zilliqa.zil]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: CKB.Nervos.ckb.instance.id), tokenName: "Nervos Network",
            symbol: CKB.Nervos.ckb.symbol,
            instances: [CKB.Nervos.ckb]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: SIA.Sia.sc.instance.id), tokenName: "Siacoin",
            symbol: SIA.Sia.sc.symbol,
            instances: [SIA.Sia.sc]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: DCR.Decred.dcr.instance.id), tokenName: "Decred",
            symbol: DCR.Decred.dcr.symbol,
            instances: [DCR.Decred.dcr]
        ),
        try! AssetDeclaration(
            asset: Asset(validating: POLKADOT.Enjin.enj.instance.id), tokenName: "Enjin Coin",
            symbol: POLKADOT.Enjin.enj.symbol,
            instances: [POLKADOT.Enjin.enj]
        )
    ] + Assets.all

    /// The namespaces this library owns, beside CAIP-2's: "exchange", "iso4217", and each chain's whose namespace
    /// CAIP's registry does not hold
    ///
    /// The CAIP namespaces registry has no namespace for exchanges and none for fiat, so the library owns these two;
    /// nor, read 2026-10-07, for NEAR (`near`), Cardano (`cip34`, CIP-34's own proposal), the Internet Computer
    /// (`icp`), Ontology (`ont`), Zilliqa (`zil`), Nervos (`ckb`), Sia (`sia`) or Decred (`dcr`), so the library owns
    /// each until CAIP registers one. If CAIP ever registers any, a test that reads the registry's recorded list is
    /// where the conflict is caught.
    public static let ownedNamespaces: Set<String> = [EXCHANGE.namespace, ISO4217.namespace, NEAR.namespace, CIP34.namespace, ICP.namespace, ONT.namespace, ZIL.namespace, CKB.namespace, SIA.namespace, DCR.namespace]

    /// A registry holding exactly `declarations`
    ///
    /// - Throws: what ``add(_:)`` throws, for the first declaration that conflicts
    public init(_ declarations: [AssetDeclaration]) throws {
        var statement = Statement()
        try statement.add(declarations)
        self.statement = statement
    }

    /// Adds declarations, add-only and conflict-checked; a declaration of an asset already declared adds the
    /// instances it lists that are not yet declared
    ///
    /// - Throws: ``AssetRegistryError/conflictingDeclaration(_:)`` when a declaration of a declared asset states its
    ///   names, units, home or a declared instance's symbol otherwise; ``AssetRegistryError/instanceInTwoAssets(_:)``
    ///   when an instance is already
    ///   another asset's; ``AssetRegistryError/decimalsChanged(_:)`` when a declared instance's decimals differ.
    ///   Nothing is added when anything throws.
    public func add(_ declarations: [AssetDeclaration]) throws {
        try withStatement { try $0.add(declarations) }
    }

    /// A refresh; never a library declaration, never a declared instance's decimals
    ///
    /// Each declaration takes the place of its asset's, or is added when its asset is not yet declared.
    ///
    /// - Throws: ``AssetRegistryError/libraryDeclaration(_:)`` for an asset this registry holds from
    ///   ``libraryDeclarations``; ``AssetRegistryError/decimalsChanged(_:)``;
    ///   ``AssetRegistryError/instanceInTwoAssets(_:)``. Nothing is replaced when anything throws.
    public func replace(_ declarations: [AssetDeclaration]) throws {
        try withStatement { try $0.replace(declarations) }
    }

    /// - Throws: ``AssetRegistryError/undeclared(_:)``
    public func declaration(of asset: Asset) throws -> AssetDeclaration {
        try read { try $0.declaration(of: asset) }
    }

    /// The decimals `instance` counts in
    ///
    /// - Throws: ``AssetRegistryError/undeclaredInstance(_:)``
    public func decimals(of instance: AssetInstance) throws -> Int {
        try read { try $0.entry(of: instance).decimals }
    }

    /// The asset `instance` is one of
    ///
    /// - Throws: ``AssetRegistryError/undeclaredInstance(_:)``
    public func asset(of instance: AssetInstance) throws -> Asset {
        try read { try $0.entry(of: instance).asset }
    }

    /// The instance of `asset` on the chain or exchange `chainId`
    ///
    /// - Throws: ``AssetRegistryError/undeclared(_:)``, ``AssetRegistryError/noInstance(_:on:)``
    public func instance(of asset: Asset, on chainId: String) throws -> AssetInstance {
        try read { statement in
            let declaration = try statement.declaration(of: asset)
            guard let found = declaration.instances.first(where: { $0.instance.chainId == chainId }) else {
                throw AssetRegistryError.noInstance(asset, on: chainId)
            }
            return found.instance
        }
    }

    /// Declares holdings that stand for currencies, add-only and conflict-checked; declaring again what is declared adds
    /// nothing
    ///
    /// Each holding is then accepted where its currency is named, one for one, with no conversion and no rate.
    ///
    /// - Throws: ``AssetRegistryError/notACurrency(_:)`` when a declaration's currency is not an `iso4217` instance;
    ///   ``AssetRegistryError/undeclaredInstance(_:)`` when a holding is not declared (the currency need not be);
    ///   ``AssetRegistryError/standsForTwoCurrencies(_:)`` when a holding already stands for another currency. Nothing
    ///   is added when anything throws.
    public func add(_ declarations: [CurrencyDeclaration]) throws {
        try withStatement { try $0.add(declarations) }
    }

    /// The one holding on the chain or exchange `chainId` that stands for `currency`
    ///
    /// ```swift
    /// try registry.holding(standingFor: ISO4217.usd.instance, on: "exchange:hyperliquid")   // Hyperliquid's USDC
    /// ```
    ///
    /// - Throws: ``AssetRegistryError/noHoldingStandsFor(_:on:)`` when none does;
    ///   ``AssetRegistryError/holdingsStandFor(_:on:_:)``, a finding naming them, when more than one does
    public func holding(standingFor currency: AssetInstance, on chainId: String) throws -> AssetInstance {
        try read { statement in
            let standing = statement.currencies
                .filter { $0.value == currency && $0.key.chainId == chainId }
                .map(\.key)
                .sorted { $0.id < $1.id }
            guard let only = standing.first else {
                throw AssetRegistryError.noHoldingStandsFor(currency, on: chainId)
            }
            guard standing.count == 1 else {
                throw AssetRegistryError.holdingsStandFor(currency, on: chainId, standing)
            }
            return only
        }
    }

    /// The currency `holding` stands for
    ///
    /// ```swift
    /// try registry.currency(of: binanceUSDT)                  // iso4217:USD
    /// ```
    ///
    /// - Throws: ``AssetRegistryError/standsForNoCurrency(_:)`` when it stands for none
    public func currency(of holding: AssetInstance) throws -> AssetInstance {
        try read { statement in
            guard let currency = statement.currencies[holding] else {
                throw AssetRegistryError.standsForNoCurrency(holding)
            }
            return currency
        }
    }

    /// Whether two instances are one asset
    ///
    /// - Throws: ``AssetRegistryError/undeclaredInstance(_:)`` when either is an instance of no declared asset
    public func isEquivalent(_ lhs: AssetInstance, _ rhs: AssetInstance) throws -> Bool {
        try read { statement in
            try statement.entry(of: lhs).asset == statement.entry(of: rhs).asset
        }
    }

    // MARK: The lock

    private func read<T>(_ body: (Statement) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(statement)
    }

    // The change is made on a copy and stored only when it completes, so a throw changes nothing.
    private func withStatement(_ body: (inout Statement) throws -> Void) rethrows {
        lock.lock()
        defer { lock.unlock() }
        var copy = statement
        try body(&copy)
        statement = copy
    }
}

/// Why a lookup in the statement, or a change to it, failed
public enum AssetRegistryError: Error, Hashable, Sendable {
    /// The asset has no declaration
    case undeclared(Asset)
    /// The instance is an instance of no declared asset
    case undeclaredInstance(AssetInstance)
    /// The asset is declared and has no instance on that chain or exchange
    case noInstance(Asset, on: String)
    /// The instance is already declared in another asset
    case instanceInTwoAssets(AssetInstance)
    /// A second declaration of a declared asset states its names, units, home or an instance's symbol otherwise
    case conflictingDeclaration(Asset)
    /// A refresh would replace one of the library's own declarations
    case libraryDeclaration(Asset)
    /// A declared instance's decimals would change
    case decimalsChanged(AssetInstance)
    /// A reference source named a chain the library's table does not map
    case unknownReferenceChain(String, by: AssetReferenceSource)
    /// A currency declaration names, as its currency, an instance outside the `iso4217` namespace
    case notACurrency(AssetInstance)
    /// The holding already stands for another currency
    case standsForTwoCurrencies(AssetInstance)
    /// No holding on that chain or exchange stands for the currency
    case noHoldingStandsFor(AssetInstance, on: String)
    /// More than one holding on that chain or exchange stands for the currency: a finding, naming them, never a pick
    case holdingsStandFor(AssetInstance, on: String, [AssetInstance])
    /// The holding stands for no currency
    case standsForNoCurrency(AssetInstance)
}

// The statement as a value, so a change is made on a copy and kept only whole.
private struct Statement {
    struct Entry {
        let asset: Asset
        let decimals: Int
    }

    private(set) var declarations: [Asset: AssetDeclaration] = [:]
    private(set) var entries: [AssetInstance: Entry] = [:]
    private(set) var fromTheLibrary: Set<Asset> = []
    /// Each holding that stands for a currency, to its currency
    private(set) var currencies: [AssetInstance: AssetInstance] = [:]

    func declaration(of asset: Asset) throws -> AssetDeclaration {
        guard let declaration = declarations[asset] else {
            throw AssetRegistryError.undeclared(asset)
        }
        return declaration
    }

    func entry(of instance: AssetInstance) throws -> Entry {
        guard let entry = entries[instance] else {
            throw AssetRegistryError.undeclaredInstance(instance)
        }
        return entry
    }

    mutating func add(_ incoming: [AssetDeclaration]) throws {
        for declaration in incoming {
            if AssetRegistry.libraryDeclarations.contains(declaration) {
                fromTheLibrary.insert(declaration.asset)
            }
            guard let existing = declarations[declaration.asset] else {
                try place(declaration.instances, in: declaration.asset)
                declarations[declaration.asset] = declaration
                continue
            }
            guard existing.describesAlike(declaration) else {
                throw AssetRegistryError.conflictingDeclaration(declaration.asset)
            }
            var merged = existing.instances
            for instance in declaration.instances {
                if let known = merged.first(where: { $0.instance == instance.instance }) {
                    guard known.decimals == instance.decimals else {
                        throw AssetRegistryError.decimalsChanged(instance.instance)
                    }
                    guard known.symbol == instance.symbol else {
                        throw AssetRegistryError.conflictingDeclaration(declaration.asset)
                    }
                    continue
                }
                try place([instance], in: declaration.asset)
                merged.append(instance)
            }
            declarations[declaration.asset] = existing.with(instances: merged)
        }
    }

    mutating func add(_ incoming: [CurrencyDeclaration]) throws {
        for declaration in incoming {
            let currency = declaration.currency
            // The currency is named by its `iso4217` id alone and need not be declared here: a registry that holds an
            // exchange's holdings without the library's dollar still learns which of them stand for it.
            guard currency.chainId == nil else {
                throw AssetRegistryError.notACurrency(currency)
            }
            for holding in declaration.holdings {
                _ = try entry(of: holding)
                if let other = currencies[holding], other != currency {
                    throw AssetRegistryError.standsForTwoCurrencies(holding)
                }
                currencies[holding] = currency
            }
        }
    }

    mutating func replace(_ incoming: [AssetDeclaration]) throws {
        for declaration in incoming {
            guard !fromTheLibrary.contains(declaration.asset) else {
                throw AssetRegistryError.libraryDeclaration(declaration.asset)
            }
            if let existing = declarations[declaration.asset] {
                for old in existing.instances {
                    if let new = declaration.instances.first(where: { $0.instance == old.instance }),
                       new.decimals != old.decimals {
                        throw AssetRegistryError.decimalsChanged(old.instance)
                    }
                    entries[old.instance] = nil
                }
            }
            try place(declaration.instances, in: declaration.asset)
            declarations[declaration.asset] = declaration
        }
    }

    // Enters each instance as one of `asset`'s, refusing an instance already another asset's.
    private mutating func place(_ instances: [AssetDeclaration.Instance], in asset: Asset) throws {
        for instance in instances {
            if let entry = entries[instance.instance], entry.asset != asset {
                throw AssetRegistryError.instanceInTwoAssets(instance.instance)
            }
            entries[instance.instance] = Entry(asset: asset, decimals: instance.decimals)
        }
    }
}

private extension AssetDeclaration {
    // Two declarations of one asset that say the same of it apart from the instances they list.
    func describesAlike(_ other: AssetDeclaration) -> Bool {
        asset == other.asset
            && tokenName == other.tokenName
            && symbol == other.symbol
            && aggregatorId == other.aggregatorId
            && wholeUnit == other.wholeUnit
            && baseUnit == other.baseUnit
            && between == other.between
            && displayUnit == other.displayUnit
            && instances.first == other.instances.first
    }

    // The same declaration listing `instances`; valid by construction, since the home and the units are kept.
    func with(instances: [Instance]) -> AssetDeclaration {
        do {
            return try AssetDeclaration(
                asset: asset, tokenName: tokenName, symbol: symbol, aggregatorId: aggregatorId,
                wholeUnit: .init(name: wholeUnit.name, symbol: wholeUnit.symbol, fractionDigits: wholeUnit.fractionDigits),
                baseUnit: baseUnit.map { .init(name: $0.name, symbol: $0.symbol, fractionDigits: $0.fractionDigits) },
                between: between, displayUnit: displayUnit, instances: instances
            )
        } catch {
            preconditionFailure("A merged declaration of \(asset.id) is not valid: \(error)")
        }
    }
}

public extension AssetRegistry {
    /// Each reference source's names for a chain, each mapped to the chain's CAIP-2 id
    ///
    /// The one place a source's chain name is translated. Each name is the source's own, verbatim; a row is added
    /// with its chain's conformer, never before. A native coin has no platform in either source, so Bitcoin has no
    /// row, and no source lists an exchange as a platform.
    static let referenceChainIds: [AssetReferenceSource: [String: String]] = [
        .coinGecko: [
            "ethereum": EIP155.Ethereum.chainId,
            "binance-smart-chain": EIP155.BinanceSmartChain.chainId,
            "polygon-pos": EIP155.Polygon.chainId,
            "optimistic-ethereum": EIP155.Optimism.chainId,
            "fantom": EIP155.Fantom.chainId,
            "tron": TRON.Tron.chainId,
            "avalanche": EIP155.Avalanche.chainId,
            "ethereum-classic": EIP155.EthereumClassic.chainId,
            "celo": EIP155.Celo.chainId,
            "base": EIP155.Base.chainId,
            "theta": EIP155.Theta.chainId,
            "coti": EIP155.COTI.chainId,
            "solana": SOLANA.Solana.chainId,
            "xrp": XRPL.XRPLedger.chainId,
            "stellar": STELLAR.Stellar.chainId,
            "tezos": TEZOS.Tezos.chainId,
            "algorand": ALGORAND.Algorand.chainId,
            "hedera-hashgraph": HEDERA.Hedera.chainId,
            "neo": NEO.Neo.chainId,
            "elrond": MVX.MultiversX.chainId,
            "stacks": STACKS.Stacks.chainId,
            "iota": IOTA.Iota.chainId,
            "vechain": VECHAIN.VeChain.chainId,
            "flow": FLOW.Flow.chainId,
            "qtum": BIP122.Qtum.chainId,
            "cosmos": COSMOS.CosmosHub.chainId,
            "thorchain": COSMOS.THORChain.chainId,
            "terra-2": COSMOS.Terra.chainId,
            "near-protocol": NEAR.Near.chainId,
            "cardano": CIP34.Cardano.chainId,
            "internet-computer": ICP.InternetComputer.chainId,
            "ontology": ONT.Ontology.chainId,
            "zilliqa": ZIL.Zilliqa.chainId
        ],
        .coinMarketCap: [
            "Ethereum": EIP155.Ethereum.chainId,
            "BNB": EIP155.BinanceSmartChain.chainId,
            "BNB Smart Chain (BEP20)": EIP155.BinanceSmartChain.chainId,
            "Polygon": EIP155.Polygon.chainId,
            "Optimism": EIP155.Optimism.chainId,
            "Fantom": EIP155.Fantom.chainId,
            "TRON": TRON.Tron.chainId,
            "Tron20": TRON.Tron.chainId,
            "Avalanche C-Chain": EIP155.Avalanche.chainId,
            "Celo": EIP155.Celo.chainId,
            "Base": EIP155.Base.chainId,
            "Solana": SOLANA.Solana.chainId,
            "Neo": NEO.Neo.chainId,
            "VeChain": VECHAIN.VeChain.chainId,
            "Cardano": CIP34.Cardano.chainId
        ]
    ]

    /// The CAIP-2 id of the chain `source` calls `name`
    ///
    /// ```swift
    /// try AssetRegistry.chainId(named: "polygon-pos", by: .coinGecko)      // "eip155:137"
    /// ```
    ///
    /// - Throws: ``AssetRegistryError/unknownReferenceChain(_:by:)``
    static func chainId(named name: String, by source: AssetReferenceSource) throws -> String {
        guard let chainId = referenceChainIds[source]?[name] else {
            throw AssetRegistryError.unknownReferenceChain(name, by: source)
        }
        return chainId
    }
}
