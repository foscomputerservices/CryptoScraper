// XRPLedgerChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for the XRP Ledger: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct XRPLedgerChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(XRPLedgerChain.default.id == "xrpl:0")
        #expect(XRPLedgerChain.default.id == XRPL.XRPLedger.chainId)
        let instance = try AssetInstance(validating: XRPLedgerChain.default.id + ":" + "shape")
        #expect(instance.chainId == XRPLedgerChain.default.id)
        #expect(XRPLedgerChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(XRPLedgerChain.default.mainContract.isChainToken)
        #expect(XRPLedgerChain.default.mainContract.address == "xrp")
        #expect(AssetInstance(XRPLedgerChain.default.mainContract).id == XRPL.XRPLedger.xrp.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(XRPLedgerChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 6)
        #expect(XRPL.XRPLedger.xrp.decimals == 6)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(XRPL.XRPLedger.xrp))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(XRPLedgerChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == XRPL.XRPLedger.xrp)
        #expect(declaration.symbol.text == "XRP")
        #expect(declaration.tokenName == "XRP")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(XRPLedgerContract.Units.xrp.divisorFromBase == Self.tenToThe(XRPL.XRPLedger.xrp.decimals))
        #expect(XRPLedgerContract.Units.defaultDisplayUnits == .xrp)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(XRPLedgerContract.Units.drop.divisorFromBase == Self.tenToThe(0))
        #expect(XRPLedgerContract.Units.chainBaseUnits == .drop)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try XRPLedgerChain.default.contract(for: "rf1BiGeXwwQoi8Z2ueFYTEXSwuJYfV2Jpn").address == "rf1BiGeXwwQoi8Z2ueFYTEXSwuJYfV2Jpn")
    }

    @Test(arguments: ["rf1BiGeXwwQoi8Z2ueFYTEXSwuJYfV2Jp0", "xf1BiGeXwwQoi8Z2ueFYTEXSwuJYfV2Jpn", "XRP.rf1BiGeXwwQoi8Z2ueFYTEXSwuJYfV2Jpn"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try XRPLedgerChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try XRPLedgerChain.default.contract(for: "rf1BiGeXwwQoi8Z2ueFYTEXSwuJYfV2Jpn")
        let decoded: XRPLedgerContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == XRPLedgerChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(XRPLedgerChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? XRPLedgerContract)
        #expect(contract == XRPLedgerChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: XRPLedgerChain.default.id + ":" + "rf1BiGeXwwQoi8Z2ueFYTEXSwuJYfV2Jpn")
        let contract = try #require(BlockChains.contract(of: account) as? XRPLedgerContract)
        #expect(contract.address == "rf1BiGeXwwQoi8Z2ueFYTEXSwuJYfV2Jpn")
    }

    /// A generated token on the chain, from CoinGecko's recorded detail: its contract through the bridge, its
    /// decimals in the shared statement
    @Test func theGeneratedUsdCoinIsItsContractAtItsDecimals() throws {
        let token = XRPL.XRPLedger.usdCoin
        let contract = try #require(BlockChains.contract(of: token.instance) as? XRPLedgerContract)
        #expect(contract.address == "5553444300000000000000000000000000000000.rGm7WCVp9gb4jZHWTEtGUr4dd74z2XuWhE")
        #expect(try AssetRegistry.shared.asset(of: token.instance) == .usdc)
        #expect(try AssetRegistry.shared.decimals(of: token.instance) == 6)
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "xrp", by: .coinGecko) == XRPLedgerChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "xrp")?.chainId == XRPLedgerChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(XRPLedgerChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(XRPLedgerChain.default.scanner.userReadableName == "rippled")
    }

    /// The recorded `account_info` of the docs' example account: 1,138,943,817 drops, at XRP's declared 6
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: Rippled.Response<Rippled.AccountInfoResponse> = try CoinGeckoRecorded.data("XRPLedger/account_info.json").fromJSON()
        let amount = try response.value().amount()
        #expect(amount.quantity == 1_138_943_817)
        #expect(amount.currency == XRPLedgerChain.default.mainContract)
        #expect(amount.value() == 1_138.943817)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 6)
    }

    /// The recorded `account_tx`: three transactions, XRP delivered only by the account's deletion, 844,647 drops
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let transactions = try XRPLedgerChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("XRPLedger/account_tx.json"))
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: XRPLedgerContract.self) }
        #expect(reads.map(\.type) == ["TrustSet", "NFTokenCreateOffer", "AccountDelete"])
        #expect(reads.map(\.quantity) == [0, 0, 844_647])
        #expect(reads.map(\.fee) == [10, 12, 200_000])
        #expect(reads.allSatisfy { $0.currency == XRPLedgerChain.default.mainContract && $0.successful })
        #expect(reads[2].from == "rLGJYJxVQfAZ95NNiWHexhH2w742mfFrj3")
        #expect(reads[2].to == "rf1BiGeXwwQoi8Z2ueFYTEXSwuJYfV2Jpn")
        #expect(reads[2].timeStamp == Date(timeIntervalSince1970: 946_684_800 + 824_414_951))
    }

    /// A refusal is thrown in the server's words, never read as a zero
    @Test func aRefusalIsThrownInTheServersWords() throws {
        let refusal = #"{"result":{"account":"rUnfundedAccount","error":"actNotFound","error_message":"Account not found.","status":"error"}}"#
        let response: Rippled.Response<Rippled.AccountInfoResponse> = try Data(refusal.utf8).fromJSON()
        #expect(throws: RippledResponseError.self) { try response.value() }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let usdc = try #require(BlockChains.contract(of: XRPL.XRPLedger.usdCoin.instance) as? XRPLedgerContract)
        let account = try XRPLedgerChain.default.contract(for: "rf1BiGeXwwQoi8Z2ueFYTEXSwuJYfV2Jpn")
        await #expect(throws: RippledResponseError.self) {
            try await XRPLedgerChain.default.scanner.getBalance(forToken: usdc, forAccount: account)
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
