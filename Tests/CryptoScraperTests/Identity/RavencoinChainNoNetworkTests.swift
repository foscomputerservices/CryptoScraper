// RavencoinChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Ravencoin:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No
/// network.
@Suite struct RavencoinChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(RavencoinChain.default.id == "bip122:0000006b444bc2f2ffe627be9d9e7e7a")
        #expect(RavencoinChain.default.id == BIP122.Ravencoin.chainId)
        let instance = try AssetInstance(validating: RavencoinChain.default.id + ":" + "shape")
        #expect(instance.chainId == RavencoinChain.default.id)
        #expect(RavencoinChain.default.id.split(separator: ":").count == 2)
    }

    /// The bip122 form: 32 lower-case hex digits after `bip122:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = RavencoinChain.default.id.dropFirst("bip122:".count)
        #expect(RavencoinChain.default.id.hasPrefix("bip122:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(RavencoinChain.default.mainContract.isChainToken)
        #expect(RavencoinChain.default.mainContract.address == "rvn")
        #expect(AssetInstance(RavencoinChain.default.mainContract).id == BIP122.Ravencoin.rvn.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(RavencoinChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(BIP122.Ravencoin.rvn.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(BIP122.Ravencoin.rvn))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(RavencoinChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == BIP122.Ravencoin.rvn)
        #expect(declaration.symbol.text == "RVN")
        #expect(declaration.tokenName == "Ravencoin")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(RavencoinContract.Units.rvn.divisorFromBase == Self.tenToThe(BIP122.Ravencoin.rvn.decimals))
        #expect(RavencoinContract.Units.defaultDisplayUnits == .rvn)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(RavencoinContract.Units.base.divisorFromBase == Self.tenToThe(0))
        #expect(RavencoinContract.Units.chainBaseUnits == .base)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["RXBurnXXXXXXXXXXXXXXXXXXXXXXWUo9FV", "r6KvDDnX1USWVKh6FUUS75MLsv5t1Gfy1c"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try RavencoinChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["rxburnxxxxxxxxxxxxxxxxxxxxxxwuo9fv", "RXBurnXXXXXXXXXXXXXXXXXXXXXXWUo9F", "16L5yRNPTuciSgXGHqYwn9N6NeoKqopAu", "DBcZSePDaMMduBMLymWHXhkE5ArFEvkagU"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try RavencoinChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try RavencoinChain.default.contract(for: "RXBurnXXXXXXXXXXXXXXXXXXXXXXWUo9FV")
        let decoded: RavencoinContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == RavencoinChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(RavencoinChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? RavencoinContract)
        #expect(contract == RavencoinChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: RavencoinChain.default.id + ":" + "RXBurnXXXXXXXXXXXXXXXXXXXXXXWUo9FV")
        let contract = try #require(BlockChains.contract(of: account) as? RavencoinContract)
        #expect(contract.address == "RXBurnXXXXXXXXXXXXXXXXXXXXXXWUo9FV")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's recorded platforms name none on Ravencoin, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(RavencoinChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(RavencoinChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsTheNilScannerReadWithNoUnwrap() {
        #expect(RavencoinChain.default.scanner.userReadableName == "No scanner")
    }

    /// Blockchair's recorded `/stats` does not list the chain, so its scanner is the ``NilScanner``
    @Test func blockchairDoesNotServeTheChain() throws {
        #expect(try !BlockchairNoNetworkTests.servedSlugs().contains("ravencoin"))
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
