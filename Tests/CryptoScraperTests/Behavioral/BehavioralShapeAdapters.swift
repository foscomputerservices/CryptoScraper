// BehavioralShapeAdapters.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// The builder's adapters for the identity PR's re-projected suites of the 2023 target (AR14's second channel, step 6),
// projected from the documents alone. Each maps one call a projected file writes onto what the code and the target's
// recordings declare: wiring only, never a behavior. No assertion of a projected file is edited; a red that is not a
// defect is disabled in place with its classification as the reason.

import CryptoAsset
import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// The projected `BNBChain`: the 2023 conformer of `eip155:56` is `BinanceSmartChain`
typealias BNBChain = BinanceSmartChain

// MARK: D21 — the 2023 token info's initializer

extension SimpleTokenInfo {
    /// The projected `SimpleTokenInfo(contract:tokenName:symbol:aggregatorId:)`: the 2023 initializer's labels are
    /// `contractAddress:` and `equivalentContracts:` (none here)
    init(contract: Contract, tokenName: String, symbol: String, aggregatorId: String?) {
        self.init(contractAddress: contract, equivalentContracts: [], tokenName: tokenName, symbol: symbol,
                  aggregatorId: aggregatorId)
    }
}

// MARK: D26 — the map's answer, and the generated namespaces' names

extension CryptoEquivalencyMap {
    /// The projected map answers a list, never an optional: the code answers `nil` for a contract that is an instance
    /// of no declared asset, read here as no contracts
    func equivalentContracts<Contract: CryptoContract>(to contract: Contract) -> [any CryptoContract] {
        let answer: [any CryptoContract]? = equivalentContracts(to: contract as any CryptoContract)
        return answer ?? []
    }

    /// The same, for an Ethereum contract written as one, where Swift would otherwise prefer the optional answer
    func equivalentContracts(to contract: EthereumContract) -> [any CryptoContract] {
        let answer: [any CryptoContract]? = equivalentContracts(to: contract as any CryptoContract)
        return answer ?? []
    }
}

extension Array where Element == any CryptoContract {
    /// The projected `.map(\.id)` over the map's answer reads each contract's id, the 2023 `id: String`; on the
    /// existential Swift would otherwise take `Identifiable`'s requirement, typed `any Hashable`
    func map(_ keyPath: KeyPath<any CryptoContract, String>) -> [String] {
        map { $0[keyPath: keyPath] }
    }
}

extension EIP155.Polygon {
    /// The projected `usdc`: the generated constant is named from CoinGecko's id, `usdCoin`, as Ethereum's alias is
    static var usdc: AssetDeclaration.Instance { usdCoin }
}

extension EIP155 {
    /// The projected `BNBSmartChain`: the code's name for `eip155:56` is `BinanceSmartChain` (the 2023 chain's)
    typealias BNBSmartChain = BinanceSmartChain
}

extension EIP155.BinanceSmartChain {
    /// The projected `usdc` on BNB Smart Chain. NOT DECLARED: CoinGecko's `usd-coin` lists no `binance-smart-chain`
    /// contract (the recorded `coin-usd-coin.json`), so the importer generated none. This placeholder is an instance on
    /// the chain that no declaration lists, never a real contract; every test that reads it is classified in place.
    static var usdc: AssetDeclaration.Instance {
        try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "usdc-not-declared"), decimals: 6, symbol: AssetSymbol(validating: "USDC")
        )
    }
}

// MARK: D15 — the 2023 fiat

extension USD {
    /// The projected `USD()`: the 2023 fiat's memberwise initializer is internal; its stub is the same value
    init() {
        self = .stub()
    }
}

// MARK: D12 — the CAIP namespaces registry's recorded list

enum CAIPRecording {
    /// The CAIP namespaces registry's 49 namespace folders, the same recording CryptoAssetTests' `Fixtures.caipNamespaces`
    /// pins (https://github.com/ChainAgnostic/namespaces, read 2026-10-07), carried here because that target's fixtures
    /// are not this one's
    static func namespaces() throws -> Set<String> {
        [
            "acknacki", "aleo", "alephium", "algorand", "antelope", "aptos", "arweave", "avalanche", "bip122", "bsv",
            "casper", "ccd", "chia", "conflux", "cosmos", "eip155", "ergo", "fil", "flow", "haneul",
            "hedera", "hive", "iota", "klv", "koinos", "mina", "monero", "mvx", "neo", "partisia",
            "polkadot", "quai", "qubic", "reef", "solana", "stacks", "starknet", "stellar", "sui", "swift",
            "tenzro", "tezos", "tron", "tvm", "vechain", "wallet", "waves", "xrpl", "xync"
        ]
    }
}

// MARK: D25 — the 2023 ladders' exponents, and Etherscan's token decimals

extension CurrencyUnits {
    /// The projected `exponent` of a 2023 unit: the power of ten its ladder states, read from `divisorFromBase`
    /// (10^exponent), the only member the ladder declares publicly
    var exponent: Int {
        var divisor = divisorFromBase
        var exponent = 0
        while divisor >= 10, divisor % 10 == 0 {
            divisor /= 10
            exponent += 1
        }
        return exponent
    }
}

/// A recorded Etherscan session by name. NOT HELD for USDC's token info: the recording of Etherscan's `tokeninfo`
/// for USDC is its refusal of a free key (`tokeninfo-ethereum-usdc-free-key-refused.json`), and the 2023 `Etherscan`
/// takes no session; the test that asks is disabled in place, and nothing here can reach the network.
enum RecordedEtherscan {
    struct Session: Sendable {
        let recording: String
    }

    static func session(answering recording: String) -> Session {
        Session(recording: recording)
    }
}

extension Etherscan {
    init(session: RecordedEtherscan.Session) {
        preconditionFailure("No recording of Etherscan's token info named \(session.recording); see the identity ledger")
    }

    /// The projected name for the token's decimals Etherscan's `divisor` states: `getInfo(forToken:)`'s `decimals`
    func tokenDecimals(for contract: EthereumContract) async throws -> Int? {
        try await getInfo(forToken: contract).decimals
    }
}
