// OntologyChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Ontology:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct OntologyChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(OntologyChain.default.id == "ont:mainnet")
        #expect(OntologyChain.default.id == ONT.Ontology.chainId)
        let instance = try AssetInstance(validating: OntologyChain.default.id + ":" + "shape")
        #expect(instance.chainId == OntologyChain.default.id)
    }

    /// CAIP-2's shape: the namespace, 3 to 8 of `[-a-z0-9]`; the reference, 1 to 32 of `[-_a-zA-Z0-9]`
    @Test func theIdIsShapedAsCAIP2() {
        let parts = OntologyChain.default.id.split(separator: ":")
        #expect(parts.count == 2)
        #expect((3...8).contains(parts[0].count))
        #expect(parts[0].allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") })
        #expect((1...32).contains(parts[1].count))
        #expect(parts[1].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
    }

    /// CAIP's registry holds no `ont` (read 2026-10-07), so the library owns the namespace in its own table
    @Test func theNamespaceIsTheLibrarys() {
        #expect(ONT.namespace == "ont")
        #expect(AssetRegistry.ownedNamespaces.contains(ONT.namespace))
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(OntologyChain.default.mainContract.isChainToken)
        #expect(OntologyChain.default.mainContract.address == "ont")
        #expect(AssetInstance(OntologyChain.default.mainContract).id == ONT.Ontology.ont.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(OntologyChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 9)
        #expect(ONT.Ontology.ont.decimals == 9)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(ONT.Ontology.ont))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(OntologyChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == ONT.Ontology.ont)
        #expect(declaration.symbol.text == "ONT")
        #expect(declaration.tokenName == "Ontology")
    }

    /// ONG, the chain's second native coin, under its own placeholder and its own declaration (design § 2.5)
    @Test func ongIsItsOwnDeclaredInstanceOnTheChain() throws {
        let ong = try OntologyChain.default.contract(for: "ong")
        #expect(!ong.isChainToken)
        #expect(AssetInstance(ong).id == ONT.Ontology.ong.instance.id)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(ong)) == 18)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: AssetInstance(ong)))
        #expect(declaration.instances.first == ONT.Ontology.ong)
        #expect(declaration.symbol.text == "ONG")
        #expect(declaration.tokenName == "Ontology Gas")
        #expect(try !AssetRegistry.shared.isEquivalent(AssetInstance(ong), AssetInstance(OntologyChain.default.mainContract)))
        let back = try #require(BlockChains.contract(of: ONT.Ontology.ong.instance) as? OntologyContract)
        #expect(back == ong)
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(OntologyContract.Units.ont.divisorFromBase == Self.tenToThe(ONT.Ontology.ont.decimals))
        #expect(OntologyContract.Units.defaultDisplayUnits == .ont)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(OntologyContract.Units.base.divisorFromBase == Self.tenToThe(0))
        #expect(OntologyContract.Units.chainBaseUnits == .base)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as the chain writes it
    @Test(arguments: ["AFmseVrdL9f9oyCzZefL9tG6UbviEH9ugK", "AFmseVrdL9f9oyCzZefL9tG6UbvhUMqNMV", "AFsCjUGzicZmXQtWpwVt6fQTZyaVe7bfEk", "0100000000000000000000000000000000000000"])
    func aWellFormedAddressIsKept(_ address: String) throws {
        #expect(try OntologyChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["NikhQp1aAD1YFCiwknhM5LQQebj4464bCJ", "AFmseVrdL9f9oyCzZefL9tG6UbviEH9ug", "AFmseVrdL9f9oyCzZefL9tG6UbviEH9ug0", "0A00000000000000000000000000000000000000", "01010101010101010101010101010101010101010", "0x0101010101010101010101010101010101010101"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try OntologyChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try OntologyChain.default.contract(for: "AFmseVrdL9f9oyCzZefL9tG6UbviEH9ugK")
        let decoded: OntologyContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == OntologyChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(OntologyChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? OntologyContract)
        #expect(contract == OntologyChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: OntologyChain.default.id + ":" + "AFmseVrdL9f9oyCzZefL9tG6UbviEH9ugK")
        let contract = try #require(BlockChains.contract(of: account) as? OntologyContract)
        #expect(contract.address == "AFmseVrdL9f9oyCzZefL9tG6UbviEH9ugK")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "ontology", by: .coinGecko) == OntologyChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "ontology")?.chainId == OntologyChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(OntologyChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(OntologyChain.default.scanner.userReadableName == "Ontology Explorer")
        #expect(OntologyExplorer.endPoint.absoluteString == "https://explorer.ont.io/v2")
    }

    /// The recorded native balances of the governance contract's address: 207,357,714.66715861 ONT, at ONT's
    /// declared 9
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: OntologyExplorer.BalancesResponse = try CoinGeckoRecorded.data("Ontology/balances.json").fromJSON()
        let amount = try response.amount(of: OntologyChain.default.mainContract)
        #expect(amount.quantity == 207_357_714_667_158_610)
        #expect(amount.currency == OntologyChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 9)
    }

    /// ONG is read from the same answer, its own row, never the unbound ONG: 41,998,525.91372468 ONG at its declared 18
    @Test func theRecordedONGIsItsOwnRowAtItsDecimals() throws {
        let response: OntologyExplorer.BalancesResponse = try CoinGeckoRecorded.data("Ontology/balances.json").fromJSON()
        let ong = try OntologyChain.default.contract(for: "ong")
        let amount = try response.amount(of: ong)
        #expect(amount.quantity == 41_998_525_913_724_680_000_000_000)
        #expect(amount.currency == ong)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(ong)) == 18)
    }

    /// The explorer writes whole coins with up to the coin's decimals of fraction; more is no amount
    @Test func anAmountInWholeCoinsIsReadExactly() {
        #expect(OntologyExplorer.baseUnits("2.01", decimals: 18) == 2_010_000_000_000_000_000)
        #expect(OntologyExplorer.baseUnits("7", decimals: 9) == 7_000_000_000)
        #expect(OntologyExplorer.baseUnits("0.0000000001", decimals: 9) == nil)
        #expect(OntologyExplorer.baseUnits("1e5", decimals: 9) == nil)
    }

    /// NOT A RECORDING: a refusal in the explorer's shape, thrown in its words
    @Test func aRefusalIsThrownInTheExplorersWords() throws {
        let shaped = #"{"code":61001,"msg":"PARAM ERROR","result":null}"#
        let response: OntologyExplorer.BalancesResponse = try Data(shaped.utf8).fromJSON()
        #expect(throws: OntologyExplorerResponseError.self) { try response.amount(of: OntologyChain.default.mainContract) }
    }

    /// The transactions read timed out when recorded, so the scanner says so rather than answer none
    @Test func theTransactionsAreNotReadAndSaySo() async throws {
        let account = try OntologyChain.default.contract(for: "AFmseVrdL9f9oyCzZefL9tG6UbviEH9ugK")
        await #expect(throws: OntologyExplorerResponseError.self) {
            try await OntologyChain.default.scanner.getTransactions(forAccount: account)
        }
        #expect(throws: OntologyExplorerResponseError.self) { try OntologyChain.default.scanner.loadTransactions(from: Data("{}".utf8)) }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try OntologyChain.default.contract(for: "AFmseVrdL9f9oyCzZefL9tG6UbviEH9ugK")
        let token = try OntologyChain.default.contract(for: "0100000000000000000000000000000000000000")
        await #expect(throws: OntologyExplorerResponseError.self) {
            try await OntologyChain.default.scanner.getBalance(forToken: token, forAccount: account)
        }
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
