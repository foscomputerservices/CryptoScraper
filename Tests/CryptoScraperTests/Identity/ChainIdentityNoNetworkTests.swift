// ChainIdentityNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoScraper
import Testing

/// Design § 1.2, § 2.2 and § 6 "Each chain, before it is admitted", for the seven chains of 2023: each id pinned to
/// its CAIP-2 string, each coin bridged to its declared instance, each ladder read against the statement. No network.
@Suite struct ChainIdentityNoNetworkTests {
    // MARK: The ids

    @Test func eachChainDeclaresItsCAIP2Id() {
        #expect(BitcoinChain.default.id == "bip122:000000000019d6689c085ae165831e93")
        #expect(EthereumChain.default.id == "eip155:1")
        #expect(BinanceSmartChain.default.id == "eip155:56")
        #expect(PolygonChain.default.id == "eip155:137")
        #expect(OptimismChain.default.id == "eip155:10")
        #expect(FantomChain.default.id == "eip155:250")
        #expect(TronChain.default.id == "tron:728126428")
    }

    @Test func eachChainsIdIsItsGeneratedConstant() {
        #expect(BitcoinChain.default.id == BIP122.Bitcoin.chainId)
        #expect(EthereumChain.default.id == EIP155.Ethereum.chainId)
        #expect(BinanceSmartChain.default.id == EIP155.BinanceSmartChain.chainId)
        #expect(PolygonChain.default.id == EIP155.Polygon.chainId)
        #expect(OptimismChain.default.id == EIP155.Optimism.chainId)
        #expect(FantomChain.default.id == EIP155.Fantom.chainId)
        #expect(TronChain.default.id == TRON.Tron.chainId)
    }

    @Test func eachChainsIdHasTheCAIP2Shape() throws {
        for id in Self.chainIds {
            let instance = try AssetInstance(validating: id + ":" + "shape")
            #expect(instance.chainId == id)
            #expect(id.split(separator: ":").count == 2)
        }
    }

    // MARK: The coins, through the bridge

    @Test func eachChainsCoinIsItsDeclaredInstance() {
        #expect(AssetInstance(BitcoinChain.default.mainContract).id == BIP122.Bitcoin.btc.instance.id)
        #expect(AssetInstance(EthereumChain.default.mainContract).id == EIP155.Ethereum.eth.instance.id)
        #expect(AssetInstance(BinanceSmartChain.default.mainContract).id == EIP155.BinanceSmartChain.bnb.instance.id)
        #expect(AssetInstance(PolygonChain.default.mainContract).id == EIP155.Polygon.pol.instance.id)
        #expect(AssetInstance(OptimismChain.default.mainContract).id == EIP155.Optimism.eth.instance.id)
        #expect(AssetInstance(FantomChain.default.mainContract).id == EIP155.Fantom.ftm.instance.id)
        #expect(AssetInstance(TronChain.default.mainContract).id == TRON.Tron.trx.instance.id)
    }

    @Test func theWellKnownAssetsAreProvenAgainstTheBridge() throws {
        #expect(AssetInstance(EthereumChain.default.mainContract).id == Asset.eth.id)
        #expect(AssetInstance(BitcoinChain.default.mainContract).id == Asset.btc.id)
        #expect(AssetInstance(USD.stub()).id == Asset.usd.id)

        // The tokens through the chain's own normalization: the address is given upper-cased and lower-cased back.
        let usdc = try EthereumChain.default.contract(for: #require(EIP155.Ethereum.usdc.instance.address).uppercased())
        let usdt = try EthereumChain.default.contract(for: #require(EIP155.Ethereum.usdt.instance.address).uppercased())
        #expect(AssetInstance(usdc).id == Asset.usdc.id)
        #expect(AssetInstance(usdt).id == Asset.usdt.id)
    }

    @Test func eachChainsCoinIsDeclaredInTheSharedStatement() throws {
        let registry = AssetRegistry.shared
        let coins: [(AssetInstance, AssetDeclaration.Instance)] = [
            (AssetInstance(BitcoinChain.default.mainContract), BIP122.Bitcoin.btc),
            (AssetInstance(EthereumChain.default.mainContract), EIP155.Ethereum.eth),
            (AssetInstance(BinanceSmartChain.default.mainContract), EIP155.BinanceSmartChain.bnb),
            (AssetInstance(PolygonChain.default.mainContract), EIP155.Polygon.pol),
            (AssetInstance(OptimismChain.default.mainContract), EIP155.Optimism.eth),
            (AssetInstance(FantomChain.default.mainContract), EIP155.Fantom.ftm),
            (AssetInstance(TronChain.default.mainContract), TRON.Tron.trx)
        ]
        for (coin, declared) in coins {
            #expect(try registry.decimals(of: coin) == declared.decimals)
            #expect(try registry.declaration(of: registry.asset(of: coin)).instances.contains(declared))
        }
    }

    @Test func optimismsEtherIsAnInstanceOfEther() throws {
        let optimism = AssetInstance(OptimismChain.default.mainContract)
        #expect(try AssetRegistry.shared.asset(of: optimism) == .eth)
        #expect(try AssetRegistry.shared.instance(of: .eth, on: OptimismChain.default.id) == optimism)
    }

    @Test func polygonsCoinIsPOLUnderItsMaticAddress() throws {
        let pol = AssetInstance(PolygonChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: pol))
        #expect(declaration.symbol.text == "POL")
        #expect(pol.address == PolygonChain.default.mainContract.address)
    }

    // MARK: The ladders against the statement (design § 2.2): left alone, read where they read true

    @Test func eachWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(BitcoinContract.Units.btc.divisorFromBase == Self.tenToThe(BIP122.Bitcoin.btc.decimals))
        #expect(EthereumContract.Units.ether.divisorFromBase == Self.tenToThe(EIP155.Ethereum.eth.decimals))
        #expect(BNBContract.Units.ether.divisorFromBase == Self.tenToThe(EIP155.BinanceSmartChain.bnb.decimals))
        #expect(MaticContract.Units.ether.divisorFromBase == Self.tenToThe(EIP155.Polygon.pol.decimals))
        #expect(OptimismContract.Units.ether.divisorFromBase == Self.tenToThe(EIP155.Optimism.eth.decimals))
        #expect(FantomContract.Units.ether.divisorFromBase == Self.tenToThe(EIP155.Fantom.ftm.decimals))
        #expect(TronContract.Units.trx.divisorFromBase == Self.tenToThe(TRON.Tron.trx.decimals))
    }

    @Test func bitcoinsBaseUnitIsTenToTheZero() {
        #expect(BitcoinContract.Units.satoshi.divisorFromBase == Self.tenToThe(0))
    }

    /// The off-by-one C2 named, stated and left alone: the statement's base unit is 10^0, the ladder reads 10^1
    @Test func weiAndSunReadTenWhereTheStatementSaysOne() {
        #expect(EthereumContract.Units.wei.divisorFromBase == Self.tenToThe(1))
        #expect(TronContract.Units.sun.divisorFromBase == Self.tenToThe(1))
        #expect(EthereumContract.Units.wei.divisorFromBase != Self.tenToThe(0))
        #expect(TronContract.Units.sun.divisorFromBase != Self.tenToThe(0))
    }

    /// The dollar's ladder, stated and left alone: it reads 10^10 for the dollar and 10^1 for the cent, where the
    /// statement counts `iso4217:USD` at 2
    @Test func theDollarsLadderReadsTenToTheTenWhereTheStatementSaysTwo() {
        #expect(USD.Units.dollars.divisorFromBase == Self.tenToThe(10))
        #expect(USD.Units.cents.divisorFromBase == Self.tenToThe(1))
        #expect(ISO4217.usd.decimals == 2)
    }

    // MARK: Helpers

    private static let chainIds: [String] = [
        BitcoinChain.default.id, EthereumChain.default.id, BinanceSmartChain.default.id, PolygonChain.default.id,
        OptimismChain.default.id, FantomChain.default.id, TronChain.default.id
    ]

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
