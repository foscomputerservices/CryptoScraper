// TezosChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Tezos: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct TezosChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(TezosChain.default.id == "tezos:NetXdQprcVkpaWU")
        #expect(TezosChain.default.id == TEZOS.Tezos.chainId)
        let instance = try AssetInstance(validating: TezosChain.default.id + ":" + "shape")
        #expect(instance.chainId == TezosChain.default.id)
        #expect(TezosChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(TezosChain.default.mainContract.isChainToken)
        #expect(TezosChain.default.mainContract.address == "xtz")
        #expect(AssetInstance(TezosChain.default.mainContract).id == TEZOS.Tezos.xtz.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(TezosChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 6)
        #expect(TEZOS.Tezos.xtz.decimals == 6)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(TEZOS.Tezos.xtz))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(TezosChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == TEZOS.Tezos.xtz)
        #expect(declaration.symbol.text == "XTZ")
        #expect(declaration.tokenName == "Tezos")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(TezosContract.Units.xtz.divisorFromBase == Self.tenToThe(TEZOS.Tezos.xtz.decimals))
        #expect(TezosContract.Units.defaultDisplayUnits == .xtz)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(TezosContract.Units.mutez.divisorFromBase == Self.tenToThe(0))
        #expect(TezosContract.Units.chainBaseUnits == .mutez)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try TezosChain.default.contract(for: "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb").address == "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb")
    }

    @Test(arguments: ["tz4VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb", "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcj0", "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcj"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try TezosChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try TezosChain.default.contract(for: "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb")
        let decoded: TezosContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == TezosChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(TezosChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? TezosContract)
        #expect(contract == TezosChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: TezosChain.default.id + ":" + "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb")
        let contract = try #require(BlockChains.contract(of: account) as? TezosContract)
        #expect(contract.address == "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "tezos", by: .coinGecko) == TezosChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "tezos")?.chainId == TezosChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(TezosChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(TezosChain.default.scanner.userReadableName == "TzKT")
    }

    /// The recorded account: 307 mutez at XTZ's declared 6
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: TzKT.AccountResponse = try CoinGeckoRecorded.data("Tezos/account.json").fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 307)
        #expect(amount.currency == TezosChain.default.mainContract)
        #expect(amount.value() == 0.000307)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 6)
    }

    /// The recorded operations: three of one transaction group, none applied (one failed, two backtracked)
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let transactions = try TezosChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("Tezos/operations.json"))
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: TezosContract.self) }
        #expect(reads.map(\.quantity) == [0, 0, 0])
        #expect(reads.map(\.fee) == [0, 0, 1_734])
        #expect(reads.allSatisfy { $0.currency == TezosChain.default.mainContract && !$0.successful })
        #expect(reads[2].from == "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb")
        #expect(reads[2].to == "KT1K8ay1iJBjGuksebrJ6XHD5knMA6rqsJL8")
        #expect(reads.allSatisfy { $0.hash == "ooY18nQPRBG4WWMCha8KptmT634CvQp3swn4wtX87MUEnPH1nke" })
    }

    /// CoinGecko's recorded Tether on Tezos states no decimals, so the importer generates no contract for it
    @Test func coinGeckosTetherOnTezosIsLeftOutForItsMissingDecimals() throws {
        let (_, report) = try AssetImporter.generate(coins: [CoinGeckoRecorded.coin("tether")], date: CoinGeckoRecorded.date)
        #expect(report.findings.contains(.noDecimals(coinId: "tether", platform: "tezos")))
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let token = try TezosChain.default.contract(for: "KT1XnTn74bUtxHfDtBmm2bGZAQfhPbvKWR8o")
        let account = try TezosChain.default.contract(for: "tz1VSUr8wwNhLAzempoch5d6hLRiTh8Cjcjb")
        await #expect(throws: TzKTResponseError.self) {
            try await TezosChain.default.scanner.getBalance(forToken: token, forAccount: account)
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
