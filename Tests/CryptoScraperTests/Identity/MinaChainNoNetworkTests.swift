// MinaChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Mina: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct MinaChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(MinaChain.default.id == "mina:mainnet")
        #expect(MinaChain.default.id == MINA.Mina.chainId)
        let instance = try AssetInstance(validating: MinaChain.default.id + ":" + "shape")
        #expect(instance.chainId == MinaChain.default.id)
        #expect(MinaChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(MinaChain.default.mainContract.isChainToken)
        #expect(MinaChain.default.mainContract.address == "mina")
        #expect(AssetInstance(MinaChain.default.mainContract).id == MINA.Mina.mina.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(MinaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 9)
        #expect(MINA.Mina.mina.decimals == 9)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(MINA.Mina.mina))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(MinaChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == MINA.Mina.mina)
        #expect(declaration.symbol.text == "MINA")
        #expect(declaration.tokenName == "Mina")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(MinaContract.Units.mina.divisorFromBase == Self.tenToThe(MINA.Mina.mina.decimals))
        #expect(MinaContract.Units.defaultDisplayUnits == .mina)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(MinaContract.Units.nanomina.divisorFromBase == Self.tenToThe(0))
        #expect(MinaContract.Units.chainBaseUnits == .nanomina)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try MinaChain.default.contract(for: "B62qmyjqEtUEZrsBpUaiz18DCkwh1ovCrJboiHbDhpvH8JEoaag5fUP").address == "B62qmyjqEtUEZrsBpUaiz18DCkwh1ovCrJboiHbDhpvH8JEoaag5fUP")
    }

    @Test(arguments: ["B61qmyjqEtUEZrsBpUaiz18DCkwh1ovCrJboiHbDhpvH8JEoaag5fUP", "B62qmyjqEtUEZrsBpUaiz18DCkwh1ovCrJboiHbDhpvH8JEoaag5fU0", "B62qmyjqEtUEZrsBpUaiz18DCkwh1ovCrJboiHbDhpvH8JEoaag5fU"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try MinaChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try MinaChain.default.contract(for: "B62qmyjqEtUEZrsBpUaiz18DCkwh1ovCrJboiHbDhpvH8JEoaag5fUP")
        let decoded: MinaContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == MinaChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(MinaChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? MinaContract)
        #expect(contract == MinaChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: MinaChain.default.id + ":" + "B62qmyjqEtUEZrsBpUaiz18DCkwh1ovCrJboiHbDhpvH8JEoaag5fUP")
        let contract = try #require(BlockChains.contract(of: account) as? MinaContract)
        #expect(contract.address == "B62qmyjqEtUEZrsBpUaiz18DCkwh1ovCrJboiHbDhpvH8JEoaag5fUP")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's recorded platforms name none for Mina, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(MinaChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(MinaChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(MinaChain.default.scanner.userReadableName == "Minascan")
    }

    /// The recorded docs' example key has no account on mainnet: no MINA, at MINA's declared 9
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: Minascan.AccountResponse = try CoinGeckoRecorded.data("Mina/account.json").fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 0)
        #expect(amount.currency == MinaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 9)
    }

    /// NOT A RECORDING: an account in the shape Mina's GraphQL documents, its total made up, read in nanomina
    @Test func anAccountInTheDocumentedShapeIsItsNanomina() throws {
        let documented = #"{"data":{"account":{"publicKey":"B62qmyjqEtUEZrsBpUaiz18DCkwh1ovCrJboiHbDhpvH8JEoaag5fUP","balance":{"total":"1500000000"}}}}"#
        let response: Minascan.AccountResponse = try Data(documented.utf8).fromJSON()
        #expect(try response.amount().quantity == 1_500_000_000)
    }

    /// The node lists no account's transactions, so the scanner says so rather than answer none
    @Test func theTransactionsAreNotReadAndSaySo() async throws {
        let account = try MinaChain.default.contract(for: "B62qmyjqEtUEZrsBpUaiz18DCkwh1ovCrJboiHbDhpvH8JEoaag5fUP")
        await #expect(throws: MinascanResponseError.self) {
            try await MinaChain.default.scanner.getTransactions(forAccount: account)
        }
        #expect(throws: MinascanResponseError.self) { try MinaChain.default.scanner.loadTransactions(from: Data("{}".utf8)) }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try MinaChain.default.contract(for: "B62qmyjqEtUEZrsBpUaiz18DCkwh1ovCrJboiHbDhpvH8JEoaag5fUP")
        await #expect(throws: MinascanResponseError.self) {
            try await MinaChain.default.scanner.getBalance(forToken: account, forAccount: account)
        }
    }


    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
