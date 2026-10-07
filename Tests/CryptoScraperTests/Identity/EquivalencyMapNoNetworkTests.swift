// EquivalencyMapNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoScraper
import Testing

/// Design § 2.6 and § 6 "The equivalence map": the 2023 map filled from the statement, and the cross-chain
/// `isEquivalent` answering in place of its `fatalError`. Each test builds its own registry. No network.
@Suite struct EquivalencyMapNoNetworkTests {
    // USDC on three chains, as the chain tables would load it: the Binance-Peg contract at 18, Polygon's native at 6.
    private let ethereumUSDC = EthereumContract(address: EIP155.Ethereum.usdc.instance.address!)
    private let bscUSDC = BNBContract(address: "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d")
    private let polygonUSDC = MaticContract(address: "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359")

    @Test func threeChainsOneClass() throws {
        let registry = try registryWithUSDCOnThreeChains()
        let map = CryptoEquivalencyMap(registry)
        let three = Set([ethereumUSDC.id, bscUSDC.id, polygonUSDC.id])

        for contract in [ethereumUSDC as any CryptoContract, bscUSDC, polygonUSDC] {
            let equivalents = try #require(map.equivalentContracts(to: contract))
            #expect(Set(equivalents.map(\.id)) == three)
            #expect(equivalents.count == 3)
        }
    }

    @Test func theListHoldsTheContractsAsTheirOwnTypes() throws {
        let registry = try registryWithUSDCOnThreeChains()
        let equivalents = try #require(CryptoEquivalencyMap(registry).equivalentContracts(to: polygonUSDC))
        #expect(equivalents.contains { $0 is EthereumContract })
        #expect(equivalents.contains { $0 is BNBContract })
        #expect(equivalents.contains { $0 is MaticContract })
    }

    @Test func anInstanceOnAChainWithNoConformerIsLeftOutOfTheList() throws {
        let registry = try registryWithUSDCOnThreeChains()
        let hyperliquid = try AssetDeclaration.Instance(
            instance: AssetInstance(validating: "exchange:hyperliquid:USDC"), decimals: 6,
            symbol: AssetSymbol(validating: "USDC")
        )
        let usdc = try registry.declaration(of: .usdc)
        try registry.add([
            AssetDeclaration(asset: .usdc, tokenName: usdc.tokenName, symbol: usdc.symbol, aggregatorId: usdc.aggregatorId,
                             instances: usdc.instances + [hyperliquid])
        ])

        let equivalents = try #require(CryptoEquivalencyMap(registry).equivalentContracts(to: ethereumUSDC))
        #expect(equivalents.count == 3)
    }

    @Test func aContractOfNoDeclaredAssetHasNoEntry() throws {
        let registry = try registryWithUSDCOnThreeChains()
        let undeclared = EthereumContract(address: "0x0000000000000000000000000000000000000042")
        #expect(CryptoEquivalencyMap(registry).equivalentContracts(to: undeclared) == nil)
    }

    @Test func crossChainContractsOfOneAssetAreEquivalent() throws {
        let registry = try registryWithUSDCOnThreeChains()
        #expect(try ethereumUSDC.isEquivalent(to: polygonUSDC, in: registry))
        #expect(try bscUSDC.isEquivalent(to: ethereumUSDC, in: registry))
    }

    @Test func optimismsEtherIsEthereumsInTheSharedStatement() throws {
        #expect(try OptimismChain.default.mainContract.isEquivalent(to: EthereumChain.default.mainContract))
    }

    // MARK: The trap is gone

    @Test func anUndeclaredContractThrowsUndeclaredInstanceNeverATrap() throws {
        let registry = try registryWithUSDCOnThreeChains()
        let undeclared = EthereumContract(address: "0x0000000000000000000000000000000000000042")
        #expect(throws: AssetRegistryError.undeclaredInstance(AssetInstance(undeclared))) {
            try undeclared.isEquivalent(to: polygonUSDC, in: registry)
        }
        #expect(throws: AssetRegistryError.undeclaredInstance(AssetInstance(undeclared))) {
            try polygonUSDC.isEquivalent(to: undeclared, in: registry)
        }
    }

    @Test func twoUnrelatedDeclaredContractsAreNotEquivalent() throws {
        let registry = try registryWithUSDCOnThreeChains()
        #expect(try !polygonUSDC.isEquivalent(to: EthereumChain.default.mainContract, in: registry))
        #expect(try !BitcoinChain.default.mainContract.isEquivalent(to: ethereumUSDC, in: registry))
    }

    // MARK: An account is an address, not an instance

    @Test func anAccountIsNoInstance() throws {
        let registry = try registryWithUSDCOnThreeChains()
        let account = EthereumContract(address: "0x00000000000000000000000000000000000000A1")

        #expect(throws: AssetRegistryError.undeclaredInstance(AssetInstance(account))) {
            try registry.asset(of: AssetInstance(account))
        }
        #expect(CryptoEquivalencyMap(registry).equivalentContracts(to: account) == nil)
        #expect(throws: AssetRegistryError.undeclaredInstance(AssetInstance(account))) {
            try account.isEquivalent(to: bscUSDC, in: registry)
        }
    }

    // MARK: Helpers

    /// The library's declarations, with USDC's class at its home alone (step 8c: the generated declaration lists its
    /// other chains, which this suite feeds through the bridge itself), grown by its BNB Smart Chain and Polygon
    /// contracts, each made from a chain-table token info through the bridge
    private func registryWithUSDCOnThreeChains() throws -> AssetRegistry {
        let generated = Assets.usdCoin
        let homeAlone = try AssetDeclaration(
            asset: generated.asset, tokenName: generated.tokenName, symbol: generated.symbol,
            aggregatorId: generated.aggregatorId, instances: [generated.instances[0]]
        )
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations.filter { $0.asset != .usdc } + [homeAlone])
        let usdc = try registry.declaration(of: .usdc)
        let bsc = try AssetDeclaration.Instance(
            SimpleTokenInfo(contractAddress: bscUSDC, equivalentContracts: [], tokenName: "USD Coin", symbol: "usdc"),
            decimals: 18
        )
        let polygon = try AssetDeclaration.Instance(
            SimpleTokenInfo(
                contractAddress: polygonUSDC, equivalentContracts: [], tokenName: "USD Coin", symbol: "usdc"
            ),
            decimals: 6
        )
        try registry.add([
            AssetDeclaration(asset: .usdc, tokenName: usdc.tokenName, symbol: usdc.symbol, aggregatorId: usdc.aggregatorId,
                             instances: usdc.instances + [bsc, polygon])
        ])
        return registry
    }
}
