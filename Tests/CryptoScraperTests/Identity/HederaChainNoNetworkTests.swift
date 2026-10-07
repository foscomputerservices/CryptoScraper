// HederaChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Hedera: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct HederaChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(HederaChain.default.id == "hedera:mainnet")
        #expect(HederaChain.default.id == HEDERA.Hedera.chainId)
        let instance = try AssetInstance(validating: HederaChain.default.id + ":" + "shape")
        #expect(instance.chainId == HederaChain.default.id)
        #expect(HederaChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(HederaChain.default.mainContract.isChainToken)
        #expect(HederaChain.default.mainContract.address == "hbar")
        #expect(AssetInstance(HederaChain.default.mainContract).id == HEDERA.Hedera.hbar.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(HederaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(HEDERA.Hedera.hbar.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(HEDERA.Hedera.hbar))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(HederaChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == HEDERA.Hedera.hbar)
        #expect(declaration.symbol.text == "HBAR")
        #expect(declaration.tokenName == "Hedera")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(HederaContract.Units.hbar.divisorFromBase == Self.tenToThe(HEDERA.Hedera.hbar.decimals))
        #expect(HederaContract.Units.defaultDisplayUnits == .hbar)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(HederaContract.Units.tinybar.divisorFromBase == Self.tenToThe(0))
        #expect(HederaContract.Units.chainBaseUnits == .tinybar)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try HederaChain.default.contract(for: "0.0.98").address == "0.0.98")
    }

    @Test(arguments: ["0.0", "0.0.98-abcde", "0.0.x"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try HederaChain.default.contract(for: address) }
    }

    /// The entity id's three numbers are its canonical form, so leading zeros go
    @Test func anAddressIsNormalizedByTheChain() throws {
        #expect(try HederaChain.default.contract(for: "0.0.098").address == "0.0.98")
        #expect(try HederaChain.default.contract(for: "00.000.456858").address == "0.0.456858")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try HederaChain.default.contract(for: "0.0.98")
        let decoded: HederaContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == HederaChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(HederaChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? HederaContract)
        #expect(contract == HederaChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: HederaChain.default.id + ":" + "0.0.98")
        let contract = try #require(BlockChains.contract(of: account) as? HederaContract)
        #expect(contract.address == "0.0.98")
    }

    /// A generated token on the chain, from CoinGecko's recorded detail: its contract through the bridge, its
    /// decimals in the shared statement
    @Test func theGeneratedUsdCoinIsItsContractAtItsDecimals() throws {
        let token = HEDERA.Hedera.usdCoin
        let contract = try #require(BlockChains.contract(of: token.instance) as? HederaContract)
        #expect(contract.address == "0.0.456858")
        #expect(try AssetRegistry.shared.asset(of: token.instance) == .usdc)
        #expect(try AssetRegistry.shared.decimals(of: token.instance) == 6)
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "hedera-hashgraph", by: .coinGecko) == HederaChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "hedera-hashgraph")?.chainId == HederaChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(HederaChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(HederaChain.default.scanner.userReadableName == "Hedera Mirror Node")
    }

    /// The recorded fee account `0.0.98`: 335,656,428,302,095 tinybars at HBAR's declared 8
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: HederaMirrorNode.AccountResponse = try CoinGeckoRecorded.data("Hedera/account.json").fromJSON()
        let amount = response.amount()
        #expect(amount.quantity == 335_656_428_302_095)
        #expect(amount.currency == HederaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 8)
    }

    /// The recorded transactions, for `0.0.98`: three transfers crediting it one tinybar each from their payer
    @Test func theRecordedTransactionsMapToTheCoinForTheAccount() throws {
        let response: HederaMirrorNode.TransactionsResponse = try CoinGeckoRecorded.data("Hedera/transactions.json").fromJSON()
        let transactions = response.cryptoTransactions(forAccount: try HederaChain.default.contract(for: "0.0.98"))
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: HederaContract.self) }
        #expect(reads.map(\.quantity) == [1, 1, 1])
        #expect(reads.allSatisfy { $0.currency == HederaChain.default.mainContract && $0.successful })
        #expect(reads.allSatisfy { $0.from == "0.0.10904488" && $0.to == "0.0.98" && $0.fee == 98_308 })
        #expect(reads[0].hash == "0.0.10904488-1791080103-000001216")
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: 1_791_080_166))
    }

    /// `loadTransactions(from:)` reads each transaction for its payer: the HBAR it paid in all
    @Test func loadTransactionsReadsThePayersSide() throws {
        let transactions = try HederaChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("Hedera/transactions.json"))
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: HederaContract.self) }
        #expect(reads.map(\.quantity) == [98_309, 98_309, 98_309])
        #expect(reads.allSatisfy { $0.from == "0.0.10904488" && $0.to == nil })
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let usdc = try #require(BlockChains.contract(of: HEDERA.Hedera.usdCoin.instance) as? HederaContract)
        let account = try HederaChain.default.contract(for: "0.0.98")
        await #expect(throws: HederaMirrorNodeResponseError.self) {
            try await HederaChain.default.scanner.getBalance(forToken: usdc, forAccount: account)
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
