// DigiByteChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for DigiByte:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No
/// network.
@Suite struct DigiByteChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(DigiByteChain.default.id == "bip122:7497ea1b465eb39f1c8f507bc877078f")
        #expect(DigiByteChain.default.id == BIP122.DigiByte.chainId)
        let instance = try AssetInstance(validating: DigiByteChain.default.id + ":" + "shape")
        #expect(instance.chainId == DigiByteChain.default.id)
        #expect(DigiByteChain.default.id.split(separator: ":").count == 2)
    }

    /// The bip122 form: 32 lower-case hex digits after `bip122:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = DigiByteChain.default.id.dropFirst("bip122:".count)
        #expect(DigiByteChain.default.id.hasPrefix("bip122:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(DigiByteChain.default.mainContract.isChainToken)
        #expect(DigiByteChain.default.mainContract.address == "dgb")
        #expect(AssetInstance(DigiByteChain.default.mainContract).id == BIP122.DigiByte.dgb.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(DigiByteChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(BIP122.DigiByte.dgb.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(BIP122.DigiByte.dgb))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(DigiByteChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == BIP122.DigiByte.dgb)
        #expect(declaration.symbol.text == "DGB")
        #expect(declaration.tokenName == "DigiByte")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(DigiByteContract.Units.dgb.divisorFromBase == Self.tenToThe(BIP122.DigiByte.dgb.decimals))
        #expect(DigiByteContract.Units.defaultDisplayUnits == .dgb)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(DigiByteContract.Units.base.divisorFromBase == Self.tenToThe(0))
        #expect(DigiByteContract.Units.chainBaseUnits == .base)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["D5ERdEN1gsouFSs7zsq7VYJxyWP6dP28H1", "SMPL7pCX7q6pEkTyoipdVgHvk9tE5D6XNW", "31nM1WuowNDzocNxPPW9NQWJEtwWpjfcLj", "dgb1qqypqxpq9qcrsszg2pvxq6rs0zqg3yyc57rkd6l"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try DigiByteChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["DGB1QQYPQXPQ9QCRSSZG2PVXQ6RS0ZQG3YYC57RKD6L", "ltc1qqypqxpq9qcrsszg2pvxq6rs0zqg3yyc5dyg36p", "16L5yRNPTuciSgXGHqYwn9N6NeoKqopAu", "D5ERdEN1gsouFSs7zsq7VYJxyWP6dP28H", "Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try DigiByteChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try DigiByteChain.default.contract(for: "D5ERdEN1gsouFSs7zsq7VYJxyWP6dP28H1")
        let decoded: DigiByteContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == DigiByteChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(DigiByteChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? DigiByteContract)
        #expect(contract == DigiByteChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: DigiByteChain.default.id + ":" + "D5ERdEN1gsouFSs7zsq7VYJxyWP6dP28H1")
        let contract = try #require(BlockChains.contract(of: account) as? DigiByteContract)
        #expect(contract.address == "D5ERdEN1gsouFSs7zsq7VYJxyWP6dP28H1")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's recorded platforms name none on DigiByte, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(DigiByteChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(DigiByteChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsTheNilScannerReadWithNoUnwrap() {
        #expect(DigiByteChain.default.scanner.userReadableName == "No scanner")
    }

    /// Blockchair's recorded `/stats` does not list the chain, so its scanner is the ``NilScanner``
    @Test func blockchairDoesNotServeTheChain() throws {
        #expect(try !BlockchairNoNetworkTests.servedSlugs().contains("digibyte"))
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
