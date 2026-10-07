// VergeChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Verge:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No
/// network.
@Suite struct VergeChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(VergeChain.default.id == "bip122:00000fc63692467faeb20cdb3b53200d")
        #expect(VergeChain.default.id == BIP122.Verge.chainId)
        let instance = try AssetInstance(validating: VergeChain.default.id + ":" + "shape")
        #expect(instance.chainId == VergeChain.default.id)
        #expect(VergeChain.default.id.split(separator: ":").count == 2)
    }

    /// The bip122 form: 32 lower-case hex digits after `bip122:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = VergeChain.default.id.dropFirst("bip122:".count)
        #expect(VergeChain.default.id.hasPrefix("bip122:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(VergeChain.default.mainContract.isChainToken)
        #expect(VergeChain.default.mainContract.address == "xvg")
        #expect(AssetInstance(VergeChain.default.mainContract).id == BIP122.Verge.xvg.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(VergeChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 6)
        #expect(BIP122.Verge.xvg.decimals == 6)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(BIP122.Verge.xvg))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(VergeChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == BIP122.Verge.xvg)
        #expect(declaration.symbol.text == "XVG")
        #expect(declaration.tokenName == "Verge")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(VergeContract.Units.xvg.divisorFromBase == Self.tenToThe(BIP122.Verge.xvg.decimals))
        #expect(VergeContract.Units.defaultDisplayUnits == .xvg)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(VergeContract.Units.base.divisorFromBase == Self.tenToThe(0))
        #expect(VergeContract.Units.chainBaseUnits == .base)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["D5ERdEN1gsouFSs7zsq7VYJxyWP6dP28H1", "EHFEaZFspRCXhkHP58q4wv8Ks29vhY28Rp", "vg1qqypqxpq9qcrsszg2pvxq6rs0zqg3yyc537fj4u"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try VergeChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["VG1QQYPQXPQ9QCRSSZG2PVXQ6RS0ZQG3YYC537FJ4U", "D5ERdEN1gsouFSs7zsq7VYJxyWP6dP28H", "16L5yRNPTuciSgXGHqYwn9N6NeoKqopAu", "Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try VergeChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try VergeChain.default.contract(for: "D5ERdEN1gsouFSs7zsq7VYJxyWP6dP28H1")
        let decoded: VergeContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == VergeChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(VergeChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? VergeContract)
        #expect(contract == VergeChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: VergeChain.default.id + ":" + "D5ERdEN1gsouFSs7zsq7VYJxyWP6dP28H1")
        let contract = try #require(BlockChains.contract(of: account) as? VergeContract)
        #expect(contract.address == "D5ERdEN1gsouFSs7zsq7VYJxyWP6dP28H1")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's recorded platforms name none on Verge, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(VergeChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(VergeChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsTheNilScannerReadWithNoUnwrap() {
        #expect(VergeChain.default.scanner.userReadableName == "No scanner")
    }

    /// Blockchair's recorded `/stats` does not list the chain, so its scanner is the ``NilScanner``
    @Test func blockchairDoesNotServeTheChain() throws {
        #expect(try !BlockchairNoNetworkTests.servedSlugs().contains("verge"))
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
