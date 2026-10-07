// AssetBridgeNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoScraper
import Testing

/// Design § 1.5 and § 2.1: the bridge from the 2023 protocols to CryptoAsset's values, and back through
/// `BlockChains.contract(of:)`. No network.
@Suite struct AssetBridgeNoNetworkTests {
    @Test func aContractsInstanceIsItsId() {
        let account = EthereumContract(address: "0x00000000000000000000000000000000000000A1")
        #expect(AssetInstance(account).id == account.id)
        #expect(AssetInstance(account).chainId == EthereumChain.default.id)
        #expect(AssetInstance(account).address == account.address)
    }

    @Test func aFiatsInstanceIsItsISO4217Code() {
        #expect(AssetInstance(USD.stub()).id == ISO4217.usd.instance.id)
        #expect(AssetInstance(USD.stub()).chainId == nil)
    }

    @Test func theContractOfACoinIsTheChainsMainContract() throws {
        let contract = try #require(BlockChains.contract(of: EIP155.Polygon.pol.instance))
        #expect(contract.isChainToken)
        #expect(contract is MaticContract)
        #expect(contract.id == PolygonChain.default.mainContract.id)
    }

    @Test func theContractOfATokenIsNormalizedByItsChain() throws {
        let address = try #require(EIP155.Ethereum.usdc.instance.address)
        let shouted = try AssetInstance(validating: EthereumChain.default.id + ":" + address.uppercased())
        let contract = try #require(BlockChains.contract(of: shouted))
        #expect(contract is EthereumContract)
        #expect(AssetInstance(contract) == EIP155.Ethereum.usdc.instance)
    }

    @Test func eachChainsCoinRoundTripsThroughTheBridge() throws {
        let coins: [AssetInstance] = [
            AssetInstance(BitcoinChain.default.mainContract), AssetInstance(EthereumChain.default.mainContract),
            AssetInstance(BinanceSmartChain.default.mainContract), AssetInstance(PolygonChain.default.mainContract),
            AssetInstance(OptimismChain.default.mainContract), AssetInstance(FantomChain.default.mainContract),
            AssetInstance(TronChain.default.mainContract)
        ]
        for coin in coins {
            let contract = try #require(BlockChains.contract(of: coin))
            #expect(AssetInstance(contract) == coin)
        }
    }

    @Test func aFiatHasNoContract() {
        #expect(BlockChains.contract(of: ISO4217.usd.instance) == nil)
    }

    @Test func anInstanceOnAChainWithNoConformerHasNoContract() throws {
        #expect(BlockChains.contract(of: AssetInstance.stub()) == nil)
        #expect(try BlockChains.contract(of: AssetInstance(validating: "exchange:kraken:XBT")) == nil)
    }

    @Test func aTokenInfoFromAChainTableIsAnInstanceWithTheDecimalsGiven() throws {
        let address = try #require(EIP155.Ethereum.usdc.instance.address)
        let info = try SimpleTokenInfo(
            contractAddress: EthereumChain.default.contract(for: address),
            equivalentContracts: [],
            tokenName: "USD Coin",
            symbol: "usdc"
        )
        #expect(try AssetDeclaration.Instance(info, decimals: 6) == EIP155.Ethereum.usdc)
    }

    @Test func aTokenInfosDecimalsOutsideTheRangeThrow() throws {
        let info = SimpleTokenInfo(
            contractAddress: TronContract(address: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"),
            equivalentContracts: [],
            tokenName: "Tether",
            symbol: "usdt"
        )
        #expect(throws: AssetError.decimalsOutOfRange(31)) {
            try AssetDeclaration.Instance(info, decimals: 31)
        }
    }

    @Test func aChainTablesTokenFeedsARegistryThroughTheBridge() throws {
        let info = SimpleTokenInfo(
            contractAddress: TronContract(address: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"),
            equivalentContracts: [],
            tokenName: "Tether",
            symbol: "usdt",
            aggregatorId: "tether"
        )
        let tronUSDT = try AssetDeclaration.Instance(info, decimals: 6)
        // Tether's class at its home alone (step 8c: the generated declaration already lists Tron's contract, which
        // this test feeds through the bridge itself)
        let generated = Assets.tether
        let homeAlone = try AssetDeclaration(
            asset: generated.asset, tokenName: generated.tokenName, symbol: generated.symbol,
            aggregatorId: generated.aggregatorId, instances: [generated.instances[0]]
        )
        let registry = try AssetRegistry(AssetRegistry.libraryDeclarations.filter { $0.asset != .usdt } + [homeAlone])
        let tether = try registry.declaration(of: .usdt)
        try registry.add([
            AssetDeclaration(
                asset: .usdt, tokenName: tether.tokenName, symbol: tether.symbol, aggregatorId: tether.aggregatorId,
                instances: tether.instances + [tronUSDT]
            )
        ])

        #expect(try registry.asset(of: AssetInstance(info.contractAddress)) == .usdt)
        #expect(try registry.decimals(of: AssetInstance(info.contractAddress)) == 6)
        #expect(tronUSDT.symbol.text == "USDT")
    }
}
