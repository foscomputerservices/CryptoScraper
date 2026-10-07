// MultiversXChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for MultiversX: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct MultiversXChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(MultiversXChain.default.id == "mvx:1")
        #expect(MultiversXChain.default.id == MVX.MultiversX.chainId)
        let instance = try AssetInstance(validating: MultiversXChain.default.id + ":" + "shape")
        #expect(instance.chainId == MultiversXChain.default.id)
        #expect(MultiversXChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(MultiversXChain.default.mainContract.isChainToken)
        #expect(MultiversXChain.default.mainContract.address == "egld")
        #expect(AssetInstance(MultiversXChain.default.mainContract).id == MVX.MultiversX.egld.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(MultiversXChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 18)
        #expect(MVX.MultiversX.egld.decimals == 18)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(MVX.MultiversX.egld))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(MultiversXChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == MVX.MultiversX.egld)
        #expect(declaration.symbol.text == "EGLD")
        #expect(declaration.tokenName == "MultiversX")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(MultiversXContract.Units.egld.divisorFromBase == Self.tenToThe(MVX.MultiversX.egld.decimals))
        #expect(MultiversXContract.Units.defaultDisplayUnits == .egld)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(MultiversXContract.Units.base.divisorFromBase == Self.tenToThe(0))
        #expect(MultiversXContract.Units.chainBaseUnits == .base)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try MultiversXChain.default.contract(for: "erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th").address == "erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th")
    }

    @Test(arguments: ["erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6t", "erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6tb", "ERD1QYU5WTHLDZR8WX5C9UCG8KJAGG0JFS53S8NR3ZPZ3HYPEFSDD8SSYCR6TH", "usdc-c76f1f", "USDC-C76F1F"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try MultiversXChain.default.contract(for: address) }
    }

    /// An ESDT token by its identifier is a contract on the chain
    @Test func anESDTIdentifierIsKeptAsGiven() throws {
        #expect(try MultiversXChain.default.contract(for: "USDC-c76f1f").address == "USDC-c76f1f")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try MultiversXChain.default.contract(for: "erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th")
        let decoded: MultiversXContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == MultiversXChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(MultiversXChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? MultiversXContract)
        #expect(contract == MultiversXChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: MultiversXChain.default.id + ":" + "erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th")
        let contract = try #require(BlockChains.contract(of: account) as? MultiversXContract)
        #expect(contract.address == "erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "elrond", by: .coinGecko) == MultiversXChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "elrond")?.chainId == MultiversXChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(MultiversXChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(MultiversXChain.default.scanner.userReadableName == "MultiversX API")
    }

    /// The recorded user account of MultiversX's docs: no EGLD, at EGLD's declared 18
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: MultiversXAPI.AccountResponse = try CoinGeckoRecorded.data("MultiversX/account.json").fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 0)
        #expect(amount.currency == MultiversXChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 18)
    }

    /// The recorded transactions: a transfer of 0.00045447 EGLD, and two stakes of 2 EGLD, both invalid; each fee
    /// its sender's
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let transactions = try MultiversXChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("MultiversX/transactions.json"))
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: MultiversXContract.self) }
        #expect(reads.map(\.quantity) == [454_470_000_000_000, 2_000_000_000_000_000_000, 2_000_000_000_000_000_000])
        #expect(reads.map(\.fee) == [50_000_000_000_000, 156_925_000_000_000, 156_925_000_000_000])
        #expect(reads.map(\.successful) == [true, false, false])
        #expect(reads.map(\.type) == ["transfer", "stake", "stake"])
        #expect(reads.allSatisfy { $0.currency == MultiversXChain.default.mainContract })
        #expect(reads.allSatisfy { $0.from == "erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th" })
        #expect(reads[0].to == "erd18zhwxzaz2an47zxdg4zftnv0epuq9nzpry6t73smv5qq5z0uzwysjjazpl")
        #expect(reads[0].hash == "95665ec701d9976cd1b4be34665c574a48fbfb410a60f03f73dde7cc466112f7")
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: 1_788_116_934))
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try MultiversXChain.default.contract(for: "erd1qyu5wthldzr8wx5c9ucg8kjagg0jfs53s8nr3zpz3hypefsdd8ssycr6th")
        let token = try MultiversXChain.default.contract(for: "USDC-c76f1f")
        await #expect(throws: MultiversXAPIResponseError.self) {
            try await MultiversXChain.default.scanner.getBalance(forToken: token, forAccount: account)
        }
    }


    /// One mapped transaction's facts, its existential opened: its amount's currency read as `C`
    private static func reading<C: CryptoContract>(
        _ transaction: some CryptoTransaction, as _: C.Type
    ) -> (hash: String, quantity: Int128, currency: C?, from: String?, to: String?, fee: Int128?, successful: Bool,
          timeStamp: Date, type: String?) {
        (transaction.hash, transaction.amount.quantity, transaction.amount.currency as? C,
         transaction.fromContract?.address, transaction.toContract?.address, transaction.gasPrice?.quantity,
         transaction.successful, transaction.timeStamp, transaction.type)
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
