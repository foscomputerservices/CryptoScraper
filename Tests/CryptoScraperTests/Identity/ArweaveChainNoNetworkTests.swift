// ArweaveChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Arweave: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct ArweaveChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(ArweaveChain.default.id == "arweave:7wIU")
        #expect(ArweaveChain.default.id == ARWEAVE.Arweave.chainId)
        let instance = try AssetInstance(validating: ArweaveChain.default.id + ":" + "shape")
        #expect(instance.chainId == ArweaveChain.default.id)
        #expect(ArweaveChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(ArweaveChain.default.mainContract.isChainToken)
        #expect(ArweaveChain.default.mainContract.address == "ar")
        #expect(AssetInstance(ArweaveChain.default.mainContract).id == ARWEAVE.Arweave.ar.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(ArweaveChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 12)
        #expect(ARWEAVE.Arweave.ar.decimals == 12)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(ARWEAVE.Arweave.ar))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(ArweaveChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == ARWEAVE.Arweave.ar)
        #expect(declaration.symbol.text == "AR")
        #expect(declaration.tokenName == "Arweave")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(ArweaveContract.Units.ar.divisorFromBase == Self.tenToThe(ARWEAVE.Arweave.ar.decimals))
        #expect(ArweaveContract.Units.defaultDisplayUnits == .ar)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(ArweaveContract.Units.winston.divisorFromBase == Self.tenToThe(0))
        #expect(ArweaveContract.Units.chainBaseUnits == .winston)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try ArweaveChain.default.contract(for: "WxLW1MWiSWcuwxmvzokahENCbWurzvwcsukFTGrqwdw").address == "WxLW1MWiSWcuwxmvzokahENCbWurzvwcsukFTGrqwdw")
    }

    @Test(arguments: ["WxLW1MWiSWcuwxmvzokahENCbWurzvwcsukFTGrqwd", "WxLW1MWiSWcuwxmvzokahENCbWurzvwcsukFTGrqwd+", "WxLW1MWiSWcuwxmvzokahENCbWurzvwcsukFTGrqwdw="])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try ArweaveChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try ArweaveChain.default.contract(for: "WxLW1MWiSWcuwxmvzokahENCbWurzvwcsukFTGrqwdw")
        let decoded: ArweaveContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == ArweaveChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(ArweaveChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? ArweaveContract)
        #expect(contract == ArweaveChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: ArweaveChain.default.id + ":" + "WxLW1MWiSWcuwxmvzokahENCbWurzvwcsukFTGrqwdw")
        let contract = try #require(BlockChains.contract(of: account) as? ArweaveContract)
        #expect(contract.address == "WxLW1MWiSWcuwxmvzokahENCbWurzvwcsukFTGrqwdw")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's recorded platforms name none for Arweave, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(ArweaveChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(ArweaveChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(ArweaveChain.default.scanner.userReadableName == "Arweave Gateway")
    }

    /// The recorded docs' example wallet: 100,000,000 winston, at AR's declared 12
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let amount = try ArweaveGateway.balance(from: CoinGeckoRecorded.data("Arweave/balance.txt"))
        #expect(amount.quantity == 100_000_000)
        #expect(amount.currency == ArweaveChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 12)
    }

    /// The recorded transactions the docs' example wallet sent are none
    @Test func theRecordedTransactionsAreEmpty() throws {
        #expect(try ArweaveChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("Arweave/graphql-transactions.json")).isEmpty)
    }

    /// NOT A RECORDING: the gateway's GraphQL in the shape Arweave's GraphQL guide gives, its values made up (the
    /// recorded answer is empty), one transfer of 1 AR seen as sent and as received, read once
    @Test func aTransactionInTheDocumentedShapeMapsToTheCoinOnce() throws {
        let node = """
        {"node":{"id":"MadeUpTransactionId","owner":{"address":"WxLW1MWiSWcuwxmvzokahENCbWurzvwcsukFTGrqwdw"},"recipient":"BNttzDav3jHVnNiV7nYbQv-GY0HQ-4XXsdkE5K9ylHQ","quantity":{"winston":"1000000000000"},"fee":{"winston":"5000"},"block":{"timestamp":1791000000}}}
        """
        let documented = #"{"data":{"sent":{"edges":["# + node + #"]},"received":{"edges":["# + node + #"]}}}"#
        let transactions = try ArweaveChain.default.scanner.loadTransactions(from: Data(documented.utf8))
        try #require(transactions.count == 1)
        let read = Self.reading(transactions[0], as: ArweaveContract.self)
        #expect(read.currency == ArweaveChain.default.mainContract)
        #expect(read.quantity == 1_000_000_000_000)
        #expect(read.fee == 5_000)
        #expect(read.from == "WxLW1MWiSWcuwxmvzokahENCbWurzvwcsukFTGrqwdw")
        #expect(read.to == "BNttzDav3jHVnNiV7nYbQv-GY0HQ-4XXsdkE5K9ylHQ")
        #expect(read.successful)
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try ArweaveChain.default.contract(for: "WxLW1MWiSWcuwxmvzokahENCbWurzvwcsukFTGrqwdw")
        await #expect(throws: ArweaveGatewayResponseError.self) {
            try await ArweaveChain.default.scanner.getBalance(forToken: account, forAccount: account)
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
