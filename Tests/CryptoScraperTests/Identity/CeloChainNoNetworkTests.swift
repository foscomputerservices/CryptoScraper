// CeloChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Celo: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No network.
@Suite struct CeloChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(CeloChain.default.id == "eip155:42220")
        #expect(CeloChain.default.id == EIP155.Celo.chainId)
        let instance = try AssetInstance(validating: CeloChain.default.id + ":" + "shape")
        #expect(instance.chainId == CeloChain.default.id)
        #expect(CeloChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(CeloChain.default.mainContract.isChainToken)
        #expect(CeloChain.default.mainContract.address == "celo")
        #expect(AssetInstance(CeloChain.default.mainContract).id == EIP155.Celo.celo.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtEighteen() throws {
        let coin = AssetInstance(CeloChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 18)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(EIP155.Celo.celo))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(CeloChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == EIP155.Celo.celo)
        #expect(declaration.symbol.text == "CELO")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(CeloContract.Units.ether.divisorFromBase == Self.tenToThe(EIP155.Celo.celo.decimals))
    }

    /// Ethereum's ladder, borrowed, keeps its off-by-one: its base unit reads 10^1 where the statement says 10^0
    @Test func weiReadsTenWhereTheStatementSaysOne() {
        #expect(CeloContract.Units.wei.divisorFromBase == Self.tenToThe(1))
    }

    // MARK: The addresses

    @Test func anAddressIsNormalizedByTheChain() throws {
        let contract = try CeloChain.default.contract(for: "0x00000000000000000000000000000000000000A1")
        #expect(contract.address == "0x00000000000000000000000000000000000000a1")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try CeloChain.default.contract(for: "0x00000000000000000000000000000000000000a1")
        let decoded: CeloContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(CeloChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? CeloContract)
        #expect(contract == CeloChain.default.mainContract)
    }

    @Test func theBridgeNormalizesAnAddressOnTheChain() throws {
        let shouted = try AssetInstance(validating: CeloChain.default.id + ":" + "0x00000000000000000000000000000000000000A1")
        let contract = try #require(BlockChains.contract(of: shouted) as? CeloContract)
        #expect(contract.address == "0x00000000000000000000000000000000000000a1")
    }

    /// A generated token on the chain, from CoinGecko's recorded detail: its contract through the bridge, its
    /// decimals in the shared statement
    @Test func aGeneratedTokenOnTheChainIsItsContractAtItsDecimals() throws {
        let usdc = EIP155.Celo.usdCoin
        let contract = try #require(BlockChains.contract(of: usdc.instance) as? CeloContract)
        #expect(contract.address == "0xceba9300f2b948710d2653dd7b07f33a8b32118c")
        #expect(try AssetRegistry.shared.asset(of: usdc.instance) == .usdc)
        #expect(try AssetRegistry.shared.decimals(of: usdc.instance) == 6)
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "celo", by: .coinGecko) == CeloChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "celo")?.chainId == CeloChain.default.id)
    }

    @Test func coinMarketCapsRowLandsOnTheChain() throws {
        let listing = """
        {
          "status": { "timestamp": "2026-10-07T00:00:00.000Z", "error_code": 0, "error_message": null,
                      "elapsed": 1, "credit_count": 1 },
          "data": [
            { "id": 3408, "name": "USDC", "symbol": "USDC", "slug": "usd-coin", "is_active": 1,
              "first_historical_data": "2018-10-08T00:00:00.000Z",
              "platform": { "id": 1, "name": "Celo", "symbol": "CELO", "slug": "celo",
                            "token_address": "0xcebA9300f2b948710d2653dD7B07f33A8B32118C" } }
          ]
        }
        """
        let response = try JSONDecoder().decode(CurrencyMapResponse.self, from: Data(listing.utf8))
        #expect(try response.tokens(for: CeloContract.self).map(\.contractAddress.address) == ["0xceba9300f2b948710d2653dd7b07f33a8b32118c"])
        #expect(try AssetRegistry.chainId(named: "Celo", by: .coinMarketCap) == CeloChain.default.id)
    }

    // MARK: The scanner

    @Test func theScannerIsV2ConfiguredForTheChainReadWithNoUnwrap() {
        #expect(CeloChain.default.scanner.userReadableName == "CeloScan")
        #expect(CeloScan.chainId == CeloChain.default.id)
        #expect(CeloScan.endPoint == Etherscan.endPoint)
    }

    /// V2's recorded chain list serves the chain, so its scanner is V2's
    @Test func v2ServesTheChain() throws {
        #expect(try EtherscanV2NoNetworkTests.servedChainIds().contains("42220"))
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
