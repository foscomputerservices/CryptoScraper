// QtumChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Qtum:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No
/// network.
@Suite struct QtumChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(QtumChain.default.id == "bip122:000075aef83cf2853580f8ae8ce6f8c3")
        #expect(QtumChain.default.id == BIP122.Qtum.chainId)
        let instance = try AssetInstance(validating: QtumChain.default.id + ":" + "shape")
        #expect(instance.chainId == QtumChain.default.id)
        #expect(QtumChain.default.id.split(separator: ":").count == 2)
    }

    /// The bip122 form: 32 lower-case hex digits after `bip122:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = QtumChain.default.id.dropFirst("bip122:".count)
        #expect(QtumChain.default.id.hasPrefix("bip122:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(QtumChain.default.mainContract.isChainToken)
        #expect(QtumChain.default.mainContract.address == "qtum")
        #expect(AssetInstance(QtumChain.default.mainContract).id == BIP122.Qtum.qtum.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(QtumChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(BIP122.Qtum.qtum.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(BIP122.Qtum.qtum))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(QtumChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == BIP122.Qtum.qtum)
        #expect(declaration.symbol.text == "QTUM")
        #expect(declaration.tokenName == "Qtum")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(QtumContract.Units.qtum.divisorFromBase == Self.tenToThe(BIP122.Qtum.qtum.decimals))
        #expect(QtumContract.Units.defaultDisplayUnits == .qtum)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(QtumContract.Units.base.divisorFromBase == Self.tenToThe(0))
        #expect(QtumContract.Units.chainBaseUnits == .base)
    }

    // MARK: The addresses

    /// Each address form the chain writes, and a QRC-20 contract in CoinGecko's form, is kept as given
    @Test(arguments: ["QLhKCGi5ZvnS9amYgdA353vzbdbWYBoxD8", "M7zVKQKmtV5Rc7erVGVVC3khZbXxsS5HEX", "qc1qqypqxpq9qcrsszg2pvxq6rs0zqg3yyc59t3ezt", "fe59cbc1704e89a698571413a81f0de9d8f00c69"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try QtumChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["QLhKCGi5ZvnS9amYgdA353vzbdbWYBoxD", "0xfe59cbc1704e89a698571413a81f0de9d8f00c69", "fe59cbc1704e89a698571413a81f0de9d8f00c6", "fe59cbc1704e89a698571413a81f0de9d8f00c6z", "16L5yRNPTuciSgXGHqYwn9N6NeoKqopAu", "QC1QQYPQXPQ9QCRSSZG2PVXQ6RS0ZQG3YYC59T3EZT"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try QtumChain.default.contract(for: address) }
    }

    /// A contract's address is a number, 40 hex digits as Qtum writes it, so its hex is lower-cased
    @Test func anAddressIsNormalizedByTheChain() throws {
        #expect(try QtumChain.default.contract(for: "FE59CBC1704E89A698571413A81F0DE9D8F00C69").address == "fe59cbc1704e89a698571413a81f0de9d8f00c69")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try QtumChain.default.contract(for: "QLhKCGi5ZvnS9amYgdA353vzbdbWYBoxD8")
        let decoded: QtumContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == QtumChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(QtumChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? QtumContract)
        #expect(contract == QtumChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: QtumChain.default.id + ":" + "QLhKCGi5ZvnS9amYgdA353vzbdbWYBoxD8")
        let contract = try #require(BlockChains.contract(of: account) as? QtumContract)
        #expect(contract.address == "QLhKCGi5ZvnS9amYgdA353vzbdbWYBoxD8")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "qtum", by: .coinGecko) == QtumChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "qtum")?.chainId == QtumChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(QtumChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsTheNilScannerReadWithNoUnwrap() {
        #expect(QtumChain.default.scanner.userReadableName == "No scanner")
    }

    /// Blockchair's recorded `/stats` does not list the chain, so its scanner is the ``NilScanner``
    @Test func blockchairDoesNotServeTheChain() throws {
        #expect(try !BlockchairNoNetworkTests.servedSlugs().contains("qtum"))
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
