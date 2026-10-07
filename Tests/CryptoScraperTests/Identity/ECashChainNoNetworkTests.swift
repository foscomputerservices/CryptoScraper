// ECashChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for eCash:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No
/// network.
@Suite struct ECashChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(ECashChain.default.id == "bip122:000000000000000004284c9d8b2c8ff7")
        #expect(ECashChain.default.id == BIP122.ECash.chainId)
        let instance = try AssetInstance(validating: ECashChain.default.id + ":" + "shape")
        #expect(instance.chainId == ECashChain.default.id)
        #expect(ECashChain.default.id.split(separator: ":").count == 2)
    }

    /// The bip122 form: 32 lower-case hex digits after `bip122:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = ECashChain.default.id.dropFirst("bip122:".count)
        #expect(ECashChain.default.id.hasPrefix("bip122:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(ECashChain.default.mainContract.isChainToken)
        #expect(ECashChain.default.mainContract.address == "xec")
        #expect(AssetInstance(ECashChain.default.mainContract).id == BIP122.ECash.xec.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(ECashChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 2)
        #expect(BIP122.ECash.xec.decimals == 2)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(BIP122.ECash.xec))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(ECashChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == BIP122.ECash.xec)
        #expect(declaration.symbol.text == "XEC")
        #expect(declaration.tokenName == "eCash")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(ECashContract.Units.xec.divisorFromBase == Self.tenToThe(BIP122.ECash.xec.decimals))
        #expect(ECashContract.Units.defaultDisplayUnits == .xec)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(ECashContract.Units.satoshi.divisorFromBase == Self.tenToThe(0))
        #expect(ECashContract.Units.chainBaseUnits == .satoshi)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07", "1BpEi6DfDAUFd7GtittLSdBeYJvcoaVggu", "31nM1WuowNDzocNxPPW9NQWJEtwWpjfcLj"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try ECashChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["bitcoincash:prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07", "ectest:prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07", "eCash:prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07", "ecash:prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz0", "ecash:zrfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07", "ecash:prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07b", "ecash:", "LKKHMBjCU89fyFNgSRprDoD8Jb25N8uWvd"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try ECashChain.default.contract(for: address) }
    }

    /// CashAddr is written all in lower or all in upper case, lower case its canonical form; CAIP-10's account holds no colon, so the address is the CashAddr body alone, its `ecash:` prefix dropped (as Bitcoin Cash's `bitcoincash:` is)
    @Test func anAddressIsNormalizedByTheChain() throws {
        #expect(try ECashChain.default.contract(for: "ecash:prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07").address == "prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07")
        #expect(try ECashChain.default.contract(for: "ECASH:PRFHCNYQNL5CGRNMLFMMS675W93LD7MVVQD0Y8LZ07").address == "prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07")
        #expect(try ECashChain.default.contract(for: "PRFHCNYQNL5CGRNMLFMMS675W93LD7MVVQD0Y8LZ07").address == "prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try ECashChain.default.contract(for: "prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07")
        let decoded: ECashContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == ECashChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(ECashChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? ECashContract)
        #expect(contract == ECashChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: ECashChain.default.id + ":" + "prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07")
        let contract = try #require(BlockChains.contract(of: account) as? ECashContract)
        #expect(contract.address == "prfhcnyqnl5cgrnmlfmms675w93ld7mvvqd0y8lz07")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's recorded platforms name none on eCash, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(ECashChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(ECashChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsTheNilScannerReadWithNoUnwrap() {
        #expect(ECashChain.default.scanner.userReadableName == "No scanner")
    }

    /// Blockchair's recorded `/stats` lists the chain, but it refused every address read when recorded, so the chain's
    /// scanner is the ``NilScanner``, not Blockchair
    @Test func blockchairServesTheChainButIsNotItsScanner() throws {
        #expect(try BlockchairNoNetworkTests.servedSlugs().contains("ecash"))
        #expect((ECashChain.default.scanner as Any) is NilScanner<ECashContract>)
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
