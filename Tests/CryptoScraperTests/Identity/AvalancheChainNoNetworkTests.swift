// AvalancheChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Avalanche C-Chain: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No network.
@Suite struct AvalancheChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(AvalancheChain.default.id == "eip155:43114")
        #expect(AvalancheChain.default.id == EIP155.Avalanche.chainId)
        let instance = try AssetInstance(validating: AvalancheChain.default.id + ":" + "shape")
        #expect(instance.chainId == AvalancheChain.default.id)
        #expect(AvalancheChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(AvalancheChain.default.mainContract.isChainToken)
        #expect(AvalancheChain.default.mainContract.address == "avax")
        #expect(AssetInstance(AvalancheChain.default.mainContract).id == EIP155.Avalanche.avax.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtEighteen() throws {
        let coin = AssetInstance(AvalancheChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 18)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(EIP155.Avalanche.avax))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(AvalancheChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == EIP155.Avalanche.avax)
        #expect(declaration.symbol.text == "AVAX")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(AvalancheContract.Units.ether.divisorFromBase == Self.tenToThe(EIP155.Avalanche.avax.decimals))
    }

    /// Ethereum's ladder, borrowed, keeps its off-by-one: its base unit reads 10^1 where the statement says 10^0
    @Test func weiReadsTenWhereTheStatementSaysOne() {
        #expect(AvalancheContract.Units.wei.divisorFromBase == Self.tenToThe(1))
    }

    // MARK: The addresses

    @Test func anAddressIsNormalizedByTheChain() throws {
        let contract = try AvalancheChain.default.contract(for: "0x00000000000000000000000000000000000000A1")
        #expect(contract.address == "0x00000000000000000000000000000000000000a1")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try AvalancheChain.default.contract(for: "0x00000000000000000000000000000000000000a1")
        let decoded: AvalancheContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(AvalancheChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? AvalancheContract)
        #expect(contract == AvalancheChain.default.mainContract)
    }

    @Test func theBridgeNormalizesAnAddressOnTheChain() throws {
        let shouted = try AssetInstance(validating: AvalancheChain.default.id + ":" + "0x00000000000000000000000000000000000000A1")
        let contract = try #require(BlockChains.contract(of: shouted) as? AvalancheContract)
        #expect(contract.address == "0x00000000000000000000000000000000000000a1")
    }

    /// A generated token on the chain, from CoinGecko's recorded detail: its contract through the bridge, its
    /// decimals in the shared statement
    @Test func aGeneratedTokenOnTheChainIsItsContractAtItsDecimals() throws {
        let usdc = EIP155.Avalanche.usdCoin
        let contract = try #require(BlockChains.contract(of: usdc.instance) as? AvalancheContract)
        #expect(contract.address == "0xb97ef9ef8734c71904d8002f8b6bc66dd9c48a6e")
        #expect(try AssetRegistry.shared.asset(of: usdc.instance) == .usdc)
        #expect(try AssetRegistry.shared.decimals(of: usdc.instance) == 6)
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "avalanche", by: .coinGecko) == AvalancheChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "avalanche")?.chainId == AvalancheChain.default.id)
    }

    @Test func coinMarketCapsRowLandsOnTheChain() throws {
        let listing = """
        {
          "status": { "timestamp": "2026-10-07T00:00:00.000Z", "error_code": 0, "error_message": null,
                      "elapsed": 1, "credit_count": 1 },
          "data": [
            { "id": 3408, "name": "USDC", "symbol": "USDC", "slug": "usd-coin", "is_active": 1,
              "first_historical_data": "2018-10-08T00:00:00.000Z",
              "platform": { "id": 1, "name": "Avalanche C-Chain", "symbol": "AVAX", "slug": "avalanche",
                            "token_address": "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E" } }
          ]
        }
        """
        let response = try JSONDecoder().decode(CurrencyMapResponse.self, from: Data(listing.utf8))
        #expect(try response.tokens(for: AvalancheContract.self).map(\.contractAddress.address) == ["0xb97ef9ef8734c71904d8002f8b6bc66dd9c48a6e"])
        #expect(try AssetRegistry.chainId(named: "Avalanche C-Chain", by: .coinMarketCap) == AvalancheChain.default.id)
    }

    // MARK: The scanner

    @Test func theScannerIsV2ConfiguredForTheChainReadWithNoUnwrap() {
        #expect(AvalancheChain.default.scanner.userReadableName == "SnowScan")
        #expect(SnowScan.chainId == AvalancheChain.default.id)
        #expect(SnowScan.endPoint == Etherscan.endPoint)
    }

    /// V2's recorded chain list serves the chain, so its scanner is V2's
    @Test func v2ServesTheChain() throws {
        #expect(try EtherscanV2NoNetworkTests.servedChainIds().contains("43114"))
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
