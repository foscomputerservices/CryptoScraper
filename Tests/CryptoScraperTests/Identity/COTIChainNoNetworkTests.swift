// COTIChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for COTI: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No network.
@Suite struct COTIChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(COTIChain.default.id == "eip155:2632500")
        #expect(COTIChain.default.id == EIP155.COTI.chainId)
        let instance = try AssetInstance(validating: COTIChain.default.id + ":" + "shape")
        #expect(instance.chainId == COTIChain.default.id)
        #expect(COTIChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(COTIChain.default.mainContract.isChainToken)
        #expect(COTIChain.default.mainContract.address == "coti")
        #expect(AssetInstance(COTIChain.default.mainContract).id == EIP155.COTI.coti.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtEighteen() throws {
        let coin = AssetInstance(COTIChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 18)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(EIP155.COTI.coti))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(COTIChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == EIP155.COTI.coti)
        #expect(declaration.symbol.text == "COTI")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(COTIContract.Units.ether.divisorFromBase == Self.tenToThe(EIP155.COTI.coti.decimals))
    }

    /// Ethereum's ladder, borrowed, keeps its off-by-one: its base unit reads 10^1 where the statement says 10^0
    @Test func weiReadsTenWhereTheStatementSaysOne() {
        #expect(COTIContract.Units.wei.divisorFromBase == Self.tenToThe(1))
    }

    // MARK: The addresses

    @Test func anAddressIsNormalizedByTheChain() throws {
        let contract = try COTIChain.default.contract(for: "0x00000000000000000000000000000000000000A1")
        #expect(contract.address == "0x00000000000000000000000000000000000000a1")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try COTIChain.default.contract(for: "0x00000000000000000000000000000000000000a1")
        let decoded: COTIContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(COTIChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? COTIContract)
        #expect(contract == COTIChain.default.mainContract)
    }

    @Test func theBridgeNormalizesAnAddressOnTheChain() throws {
        let shouted = try AssetInstance(validating: COTIChain.default.id + ":" + "0x00000000000000000000000000000000000000A1")
        let contract = try #require(BlockChains.contract(of: shouted) as? COTIContract)
        #expect(contract.address == "0x00000000000000000000000000000000000000a1")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "coti", by: .coinGecko) == COTIChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "coti")?.chainId == COTIChain.default.id)
    }

    /// CoinMarketCap's recorded listing (2026-09-13) names no platform for this chain, so the table has no
    /// CoinMarketCap row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(!(AssetRegistry.referenceChainIds[.coinMarketCap] ?? [:]).values.contains(COTIChain.default.id))
    }

    // MARK: The scanner

    @Test func theScannerIsTheNilScannerReadWithNoUnwrap() {
        #expect(COTIChain.default.scanner.userReadableName == "No scanner")
    }

    /// V2's recorded chain list does not serve the chain, so its scanner is the ``NilScanner``
    @Test func v2DoesNotServeTheChain() throws {
        #expect(try !EtherscanV2NoNetworkTests.servedChainIds().contains("2632500"))
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
