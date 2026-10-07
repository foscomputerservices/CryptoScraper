// BlockChains.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// The block chains this library supports
public enum BlockChains {
    // Read and set by whichever domain initializes the library, so it is held behind a `Mutex`.
    private static let initialized = Mutex<Bool>(false)

    /// Initializes all of the supported block chains
    ///
    /// All supported block chains are initialized and loaded with the crypto coin specifications
    /// that are known to the provided ``CryptoDataAggregator``
    ///
    /// - Throws: ``BlockChainError/alreadyInitialized`` on a second call, and whatever a chain's
    ///   `loadChainTokens(from:)` throws
    static func initializeChains(dataAggregator: CryptoDataAggregator) async throws {
        guard !initialized.withLock({ $0 }) else { throw BlockChainError.alreadyInitialized }

        for chain in knownBlockChains {
            try await chain.loadChainTokens(from: dataAggregator)
        }

        initialized.withLock { $0 = true }
    }

    /// Returns all of the block chains supported by the framework
    static var knownBlockChains: [any CryptoChain] { [
        BitcoinChain.default,
        EthereumChain.default,
        FantomChain.default,
        BinanceSmartChain.default,
        PolygonChain.default,
        OptimismChain.default,
        TronChain.default,
        AvalancheChain.default,
        EthereumClassicChain.default,
        CeloChain.default,
        BaseChain.default,
        ThetaChain.default,
        COTIChain.default,
        SolanaChain.default,
        XRPLedgerChain.default,
        StellarChain.default,
        TezosChain.default,
        AlgorandChain.default,
        HederaChain.default,
        NeoChain.default,
        FilecoinChain.default,
        MultiversXChain.default,
        StacksChain.default,
        IotaChain.default,
        VeChainChain.default,
        ArweaveChain.default,
        MinaChain.default,
        ConfluxChain.default,
        FlowChain.default,
        LitecoinChain.default,
        DogecoinChain.default,
        BitcoinCashChain.default,
        DashChain.default,
        DigiByteChain.default,
        RavencoinChain.default,
        ZcashChain.default,
        VergeChain.default,
        QtumChain.default,
        ECashChain.default,
        CosmosHubChain.default,
        THORChainChain.default,
        TerraChain.default,
        FetchAIChain.default,
        PolkadotChain.default,
        KusamaChain.default,
        NearChain.default,
        CardanoChain.default,
        InternetComputerChain.default,
        OntologyChain.default,
        ZilliqaChain.default,
        NervosChain.default,
        SiaChain.default,
        DecredChain.default,
        EnjinChain.default
    ] }

    /// Makes `chain` known to ``contract(of:)``, beside the chains of this library: an exchange chain, declared in
    /// the package's CryptoOHLCV library, which this target cannot see
    ///
    /// Registering a chain whose id is already known changes nothing, so registering twice is registering once.
    ///
    /// ```swift
    /// BlockChains.register(KrakenExchangeChain.default)
    /// BlockChains.contract(of: AssetInstance(KrakenHolding.xbt))      // the holding
    /// ```
    public static func register(_ chain: some CryptoChain & Sendable) {
        registered.withLock { chains in
            guard !chains.contains(where: { $0.id == chain.id }) else { return }
            chains.append(chain)
        }
    }

    // The chains registered from outside this target, read and added from any concurrency domain.
    private static let registered = Mutex<[any CryptoChain & Sendable]>([])

    /// The contract an instance names, on a chain or an exchange this library knows; `nil` for a fiat
    ///
    /// The chain is the one of ``knownBlockChains``, or of the chains ``register(_:)`` was given, whose `id` is the
    /// instance's chain id; the contract is made through that chain's ``CryptoChain/contract(for:)``, so its address
    /// is normalized as the chain normalizes it. `nil` too for an instance on a chain this library has no conformer
    /// for and no one has registered, or an address that chain's `contract(for:)` refuses (an exchange chain's
    /// account, which its table does not list).
    ///
    /// ```swift
    /// BlockChains.contract(of: try AssetInstance(validating: "eip155:1:eth"))?.isChainToken     // true
    /// ```
    public static func contract(of instance: AssetInstance) -> (any CryptoContract)? {
        guard let chainId = instance.chainId, let address = instance.address else {
            return nil
        }
        if let chain = knownBlockChains.first(where: { $0.id == chainId }) {
            return try? chain.contract(for: address)
        }
        let registeredChain: (any CryptoChain & Sendable)? = registered.withLock { chains in
            chains.first { $0.id == chainId }
        }
        guard let registeredChain else {
            return nil
        }
        return try? registeredChain.contract(for: address)
    }
}

public enum BlockChainError: Error, Equatable {
    case alreadyInitialized

    /// The address is not one the chain's `contract(for:)` accepts, as the package's importer and exchange clients
    /// name the same refusal
    case malformedAddress(_ address: String)

    /// The address is a shielded one, which the chain's `contract(for:)` refuses: only a transparent address is a
    /// contract (Zcash's Sprout `zc…`, Sapling `zs1…` and unified `u1…` addresses)
    case shieldedAddress(_ address: String)

    /// The text is a principal, which names a canister or a user, not an account, so the chain's `contract(for:)`
    /// refuses it: only an account identifier is an account (the Internet Computer's)
    case notAnAccount(_ text: String)

    public var localizedError: String {
        switch self {
        case .alreadyInitialized:
            return "The library has already been initialized"
        case .malformedAddress(let address):
            return "The address \(address) is not one of the chain's"
        case .shieldedAddress(let address):
            return "The address \(address) is shielded; only a transparent address is read"
        case .notAnAccount(let text):
            return "\(text) is a principal, not an account; only an account identifier is read"
        }
    }
}
