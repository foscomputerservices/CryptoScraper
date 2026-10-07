// D26 — The owner's map and cross-chain isEquivalent, answered by the statement.
// Projected from plans/2026-10-06-cryptoasset-identity-design.md § 2.6: "Your map, one entry per declared asset, its
// instances as your contracts on your chains and exchanges" and "Whether `other` is an instance of the same asset, on
// this chain, another chain, or an exchange ... Replaces the `fatalError` of 2023 ... Throws
// ``AssetRegistryError/undeclaredInstance(_:)`` when either is an instance of no declared asset". And § 6: "Three chains,
// one class ... `CryptoEquivalencyMap(registry).equivalentContracts(to:)` of any of them returns all three as your
// contracts." and "The trap is gone: your cross-chain `isEquivalent` on an undeclared contract throws
// `undeclaredInstance`; on two unrelated declared contracts it returns `false`."

import CryptoAsset
import CryptoScraper
import Foundation
import Testing

@Suite("D26 Equivalency map")
struct D26_EquivalencyMapTests {
    private let ethereumUSDC = EthereumContract(address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
    private let ethereumUSDT = EthereumContract(address: "0xdac17f958d2ee523a2206206994597c13d831ec7")

    // invented: EIP155.BNBSmartChain.usdc — BNB Smart Chain's generated enum name is not declared
    private let threeInstances = [EIP155.Ethereum.usdc.instance, EIP155.BNBSmartChain.usdc.instance, EIP155.Polygon.usdc.instance]

    // "`CryptoEquivalencyMap(registry).equivalentContracts(to:)` of any of them returns all three as your contracts"
    @Test(.disabled("Classified 2026-10-07: needs USDC on BNB Smart Chain (EIP155.BinanceSmartChain's usdc), not declared: CoinGecko's usd-coin lists no binance-smart-chain contract (the recorded coin-usd-coin.json), so the importer generated none; see the identity ledger")) func equivalentContractsReturnsAllThree() throws {
        let registry = try AssetRegistry([Assets.usdCoin])
        let map = CryptoEquivalencyMap(registry)
        for instance in threeInstances {
            let contract = try #require(BlockChains.contract(of: instance))
            let ids = Set(map.equivalentContracts(to: contract).map(\.id))
            #expect(ids.isSuperset(of: threeInstances.map(\.id)))
        }
    }

    // "its instances as your contracts on your chains" — each is a contract of its own chain's type
    @Test func equivalentContractsAreTheirChainsContracts() throws {
        let map = CryptoEquivalencyMap(try AssetRegistry([Assets.usdCoin]))
        let contracts = map.equivalentContracts(to: ethereumUSDC)
        #expect(contracts.contains { ($0 as? EthereumContract) == ethereumUSDC })
    }

    // "Whether `other` is an instance of the same asset, on ... another chain" — true across chains
    @Test func crossChainIsEquivalentIsTrue() throws {
        let registry = try AssetRegistry([Assets.usdCoin])
        let polygon = try #require(BlockChains.contract(of: EIP155.Polygon.usdc.instance))
        // `polygon` is `any CryptoContract`; open it to call the generic
        func check<Other: CryptoContract>(_ other: Other) throws -> Bool { try ethereumUSDC.isEquivalent(to: other, in: registry) }
        #expect(try check(polygon))
    }

    // "on two unrelated declared contracts it returns `false`"
    @Test func unrelatedDeclaredContractsAreNotEquivalent() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        #expect(try !ethereumUSDC.isEquivalent(to: ethereumUSDT, in: registry))
    }

    // "your cross-chain `isEquivalent` on an undeclared contract throws `undeclaredInstance`"
    @Test func undeclaredContractThrows() throws {
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations)
        // a contract no declaration lists: the zero address on Ethereum
        let stranger = EthereumContract(address: "0x0000000000000000000000000000000000000000")
        #expect(throws: AssetRegistryError.undeclaredInstance(AssetInstance(stranger))) {
            try ethereumUSDC.isEquivalent(to: stranger, in: registry)
        }
    }

    // "A cross-chain answer the map cannot give is a typed error, never a trap and never a guessed `false`." — either side undeclared
    @Test func undeclaredReceiverThrows() throws {
        let registry = try AssetRegistry([Assets.usdCoin])
        #expect(throws: AssetRegistryError.undeclaredInstance(AssetInstance(ethereumUSDT))) {
            try ethereumUSDT.isEquivalent(to: ethereumUSDC, in: registry)
        }
    }

    // "the one-chain `isEquivalent(to: Chain.Contract)` through `TokenInfo` stays" — same contract on one chain answers
    @Test func sameContractIsEquivalentToItself() throws {
        let registry = try AssetRegistry([Assets.usdCoin])
        #expect(try ethereumUSDC.isEquivalent(to: EthereumContract(address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"), in: registry))
    }

    // "An asset is one entry of your map." — one entry per declared asset
    @Test func oneEntryPerDeclaredAsset() throws {
        let map = CryptoEquivalencyMap(try AssetRegistry(AssetRegistry.libraryDeclarations))
        let tetherClass = map.equivalentContracts(to: ethereumUSDT).map(\.id)
        #expect(!tetherClass.contains(AssetInstance(ethereumUSDC).id))
        #expect(tetherClass.contains(AssetInstance(ethereumUSDT).id))
    }
}
