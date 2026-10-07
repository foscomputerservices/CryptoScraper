// ThetaChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Theta: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No network.
@Suite struct ThetaChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(ThetaChain.default.id == "eip155:361")
        #expect(ThetaChain.default.id == EIP155.Theta.chainId)
        let instance = try AssetInstance(validating: ThetaChain.default.id + ":" + "shape")
        #expect(instance.chainId == ThetaChain.default.id)
        #expect(ThetaChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(ThetaChain.default.mainContract.isChainToken)
        #expect(ThetaChain.default.mainContract.address == "tfuel")
        #expect(AssetInstance(ThetaChain.default.mainContract).id == EIP155.Theta.tfuel.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtEighteen() throws {
        let coin = AssetInstance(ThetaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 18)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(EIP155.Theta.tfuel))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(ThetaChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == EIP155.Theta.tfuel)
        #expect(declaration.symbol.text == "TFUEL")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(ThetaContract.Units.ether.divisorFromBase == Self.tenToThe(EIP155.Theta.tfuel.decimals))
    }

    /// Ethereum's ladder, borrowed, keeps its off-by-one: its base unit reads 10^1 where the statement says 10^0
    @Test func weiReadsTenWhereTheStatementSaysOne() {
        #expect(ThetaContract.Units.wei.divisorFromBase == Self.tenToThe(1))
    }

    // MARK: The addresses

    @Test func anAddressIsNormalizedByTheChain() throws {
        let contract = try ThetaChain.default.contract(for: "0x00000000000000000000000000000000000000A1")
        #expect(contract.address == "0x00000000000000000000000000000000000000a1")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try ThetaChain.default.contract(for: "0x00000000000000000000000000000000000000a1")
        let decoded: ThetaContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(ThetaChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? ThetaContract)
        #expect(contract == ThetaChain.default.mainContract)
    }

    @Test func theBridgeNormalizesAnAddressOnTheChain() throws {
        let shouted = try AssetInstance(validating: ThetaChain.default.id + ":" + "0x00000000000000000000000000000000000000A1")
        let contract = try #require(BlockChains.contract(of: shouted) as? ThetaContract)
        #expect(contract.address == "0x00000000000000000000000000000000000000a1")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "theta", by: .coinGecko) == ThetaChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "theta")?.chainId == ThetaChain.default.id)
    }

    /// CoinMarketCap's recorded listing (2026-09-13) names no platform for this chain, so the table has no
    /// CoinMarketCap row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(!(AssetRegistry.referenceChainIds[.coinMarketCap] ?? [:]).values.contains(ThetaChain.default.id))
    }

    // MARK: The scanner

    @Test func theScannerIsTheNilScannerReadWithNoUnwrap() {
        #expect(ThetaChain.default.scanner.userReadableName == "No scanner")
    }

    /// V2's recorded chain list does not serve the chain, so its scanner is the ``NilScanner``
    @Test func v2DoesNotServeTheChain() throws {
        #expect(try !EtherscanV2NoNetworkTests.servedChainIds().contains("361"))
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
