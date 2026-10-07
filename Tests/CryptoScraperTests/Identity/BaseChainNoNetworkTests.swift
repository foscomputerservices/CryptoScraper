// BaseChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Base: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No network.
@Suite struct BaseChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(BaseChain.default.id == "eip155:8453")
        #expect(BaseChain.default.id == EIP155.Base.chainId)
        let instance = try AssetInstance(validating: BaseChain.default.id + ":" + "shape")
        #expect(instance.chainId == BaseChain.default.id)
        #expect(BaseChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(BaseChain.default.mainContract.isChainToken)
        #expect(BaseChain.default.mainContract.address == "eth")
        #expect(AssetInstance(BaseChain.default.mainContract).id == EIP155.Base.eth.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtEighteen() throws {
        let coin = AssetInstance(BaseChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 18)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(EIP155.Base.eth))
    }

    /// Its coin is an instance of Ethereum's ether, as Optimism's is, never an asset of its own
    @Test func theCoinIsAnInstanceOfEther() throws {
        let coin = AssetInstance(BaseChain.default.mainContract)
        #expect(try AssetRegistry.shared.asset(of: coin) == .eth)
        #expect(try AssetRegistry.shared.instance(of: .eth, on: BaseChain.default.id) == coin)
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(BaseContract.Units.ether.divisorFromBase == Self.tenToThe(EIP155.Base.eth.decimals))
    }

    /// Ethereum's ladder, borrowed, keeps its off-by-one: its base unit reads 10^1 where the statement says 10^0
    @Test func weiReadsTenWhereTheStatementSaysOne() {
        #expect(BaseContract.Units.wei.divisorFromBase == Self.tenToThe(1))
    }

    // MARK: The addresses

    @Test func anAddressIsNormalizedByTheChain() throws {
        let contract = try BaseChain.default.contract(for: "0x00000000000000000000000000000000000000A1")
        #expect(contract.address == "0x00000000000000000000000000000000000000a1")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try BaseChain.default.contract(for: "0x00000000000000000000000000000000000000a1")
        let decoded: BaseContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(BaseChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? BaseContract)
        #expect(contract == BaseChain.default.mainContract)
    }

    @Test func theBridgeNormalizesAnAddressOnTheChain() throws {
        let shouted = try AssetInstance(validating: BaseChain.default.id + ":" + "0x00000000000000000000000000000000000000A1")
        let contract = try #require(BlockChains.contract(of: shouted) as? BaseContract)
        #expect(contract.address == "0x00000000000000000000000000000000000000a1")
    }

    /// A generated token on the chain, from CoinGecko's recorded detail: its contract through the bridge, its
    /// decimals in the shared statement
    @Test func aGeneratedTokenOnTheChainIsItsContractAtItsDecimals() throws {
        let usdc = EIP155.Base.usdCoin
        let contract = try #require(BlockChains.contract(of: usdc.instance) as? BaseContract)
        #expect(contract.address == "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913")
        #expect(try AssetRegistry.shared.asset(of: usdc.instance) == .usdc)
        #expect(try AssetRegistry.shared.decimals(of: usdc.instance) == 6)
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "base", by: .coinGecko) == BaseChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "base")?.chainId == BaseChain.default.id)
    }

    @Test func coinMarketCapsRowLandsOnTheChain() throws {
        let listing = """
        {
          "status": { "timestamp": "2026-10-07T00:00:00.000Z", "error_code": 0, "error_message": null,
                      "elapsed": 1, "credit_count": 1 },
          "data": [
            { "id": 3408, "name": "USDC", "symbol": "USDC", "slug": "usd-coin", "is_active": 1,
              "first_historical_data": "2018-10-08T00:00:00.000Z",
              "platform": { "id": 1, "name": "Base", "symbol": "ETH", "slug": "base",
                            "token_address": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" } }
          ]
        }
        """
        let response = try JSONDecoder().decode(CurrencyMapResponse.self, from: Data(listing.utf8))
        #expect(try response.tokens(for: BaseContract.self).map(\.contractAddress.address) == ["0x833589fcd6edb6e08f4c7c32d4f71b54bda02913"])
        #expect(try AssetRegistry.chainId(named: "Base", by: .coinMarketCap) == BaseChain.default.id)
    }

    // MARK: The scanner

    @Test func theScannerIsV2ConfiguredForTheChainReadWithNoUnwrap() {
        #expect(BaseChain.default.scanner.userReadableName == "BaseScan")
        #expect(BaseScan.chainId == BaseChain.default.id)
        #expect(BaseScan.endPoint == Etherscan.endPoint)
    }

    /// V2's recorded chain list serves the chain, so its scanner is V2's
    @Test func v2ServesTheChain() throws {
        #expect(try EtherscanV2NoNetworkTests.servedChainIds().contains("8453"))
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
