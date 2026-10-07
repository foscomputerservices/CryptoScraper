// ZcashChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Zcash:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No
/// network.
@Suite struct ZcashChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(ZcashChain.default.id == "bip122:00040fe8ec8471911baa1db1266ea15d")
        #expect(ZcashChain.default.id == BIP122.Zcash.chainId)
        let instance = try AssetInstance(validating: ZcashChain.default.id + ":" + "shape")
        #expect(instance.chainId == ZcashChain.default.id)
        #expect(ZcashChain.default.id.split(separator: ":").count == 2)
    }

    /// The bip122 form: 32 lower-case hex digits after `bip122:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = ZcashChain.default.id.dropFirst("bip122:".count)
        #expect(ZcashChain.default.id.hasPrefix("bip122:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(ZcashChain.default.mainContract.isChainToken)
        #expect(ZcashChain.default.mainContract.address == "zec")
        #expect(AssetInstance(ZcashChain.default.mainContract).id == BIP122.Zcash.zec.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(ZcashChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(BIP122.Zcash.zec.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(BIP122.Zcash.zec))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(ZcashChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == BIP122.Zcash.zec)
        #expect(declaration.symbol.text == "ZEC")
        #expect(declaration.tokenName == "Zcash")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(ZcashContract.Units.zec.divisorFromBase == Self.tenToThe(BIP122.Zcash.zec.decimals))
        #expect(ZcashContract.Units.defaultDisplayUnits == .zec)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(ZcashContract.Units.zatoshi.divisorFromBase == Self.tenToThe(0))
        #expect(ZcashContract.Units.chainBaseUnits == .zatoshi)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["t3Vz22vK5z2LcKEdg16Yv4FFneEL1zg9ojd", "t1Hxw6JqWMnhDK5jRCieg5bFHM2qt7UtQvu"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try ZcashChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["T3Vz22vK5z2LcKEdg16Yv4FFneEL1zg9ojd", "t3Vz22vK5z2LcKEdg16Yv4FFneEL1zg9oj", "16L5yRNPTuciSgXGHqYwn9N6NeoKqopAu", "tex1qqypqxpq9qcrsszg2pvxq6rs0zqg3yyc5dyg36p"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try ZcashChain.default.contract(for: address) }
    }

    /// A shielded address is refused with its own reason: only a transparent address is read (a Sprout `zc…`, a
    /// Sapling `zs1…` and a unified `u1…` address, each made up in its shape)
    @Test(arguments: ["zc8E7R3StiJq1T1UaCdygazuEVBe9xddGdYBLMe8WNgnBTVRGiGwY9MEeVKqhWNtmbPmwi4S1uJtPobqCq4azuLJrKCFjcj",
                      "zs1qqypqxpq9qcrsszg2pvxq6rs0zqg3yyc5z5tpwxqergd3c8g7rusqqsyqcyq5rqwzqfpg9scrgwpugpzysnz",
                      "u1qqypqxpq9qcrsszg2pvxq6rs0zqg3yyc5z5tpwxqergd3c8g7rusqqsyqcyq5rqwzqfpg9scrgwpugpzysnzs23v9ccrydpk8qarc0s"])
    func aShieldedAddressIsRefusedAsShielded(_ address: String) {
        #expect(throws: BlockChainError.shieldedAddress(address)) { try ZcashChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try ZcashChain.default.contract(for: "t3Vz22vK5z2LcKEdg16Yv4FFneEL1zg9ojd")
        let decoded: ZcashContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == ZcashChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(ZcashChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? ZcashContract)
        #expect(contract == ZcashChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: ZcashChain.default.id + ":" + "t3Vz22vK5z2LcKEdg16Yv4FFneEL1zg9ojd")
        let contract = try #require(BlockChains.contract(of: account) as? ZcashContract)
        #expect(contract.address == "t3Vz22vK5z2LcKEdg16Yv4FFneEL1zg9ojd")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's recorded platforms name none on Zcash, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(ZcashChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(ZcashChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsBlockchairForTheChainReadWithNoUnwrap() {
        #expect(ZcashChain.default.scanner.userReadableName == "Blockchair")
        #expect(ZcashChain.default.scanner.slug == "zcash")
    }

    /// Blockchair's recorded `/stats` lists the chain by its slug
    @Test func blockchairServesTheChain() throws {
        #expect(try BlockchairNoNetworkTests.servedSlugs().contains("zcash"))
    }

    /// The recorded read of `t3Vz22vK5z2LcKEdg16Yv4FFneEL1zg9ojd`: Blockchair refused it (430, the address read
    /// rate-limited by IP), and the
    /// refusal is thrown in its words
    @Test func theRecordedRefusalIsThrownInBlockchairsWords() throws {
        let response: Blockchair<ZcashContract>.DashboardResponse = try CoinGeckoRecorded.data("Zcash/dashboards-address.json").fromJSON()
        #expect(response.context.code == 430)
        #expect(response.data == nil)
        let error = #expect(throws: BlockchairResponseError.self) { try response.amount() }
        guard case .requestFailed(let words)? = error else {
            Issue.record("the refusal is not requestFailed: \(String(describing: error))")
            return
        }
        #expect(words.hasPrefix("Your IP address is temporary blacklisted"))
    }

    /// NOT A RECORDING: an address dashboard in the shape Blockchair's API gives, its values made up (the recorded
    /// read was refused): the balance in the chain's base unit, at ZEC's declared 8
    @Test func aBalanceInTheDashboardsShapeIsTheCoinAtItsDecimals() throws {
        let response: Blockchair<ZcashContract>.DashboardResponse = try Data(Self.documented.utf8).fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 150_000_000)
        #expect(amount.currency == ZcashChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 8)
    }

    /// NOT A RECORDING, as above: a send and a receipt, each the size of the address's balance change
    @Test func transactionsInTheDashboardsShapeMapToTheCoin() throws {
        let transactions = try ZcashChain.default.scanner.loadTransactions(from: Data(Self.documented.utf8))
        try #require(transactions.count == 2)
        let reads = transactions.map { Self.reading($0, as: ZcashContract.self) }
        #expect(reads.map(\.quantity) == [50_000_000, 200_000_000])
        #expect(reads.map(\.from) == ["t3Vz22vK5z2LcKEdg16Yv4FFneEL1zg9ojd", nil])
        #expect(reads.map(\.to) == [nil, "t3Vz22vK5z2LcKEdg16Yv4FFneEL1zg9ojd"])
        #expect(reads.allSatisfy { $0.currency == ZcashChain.default.mainContract && $0.successful && $0.fee == nil })
        #expect(reads.map(\.hash) == [String(repeating: "a", count: 64), String(repeating: "b", count: 64)])
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: 1_767_225_600))
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try ZcashChain.default.contract(for: "t3Vz22vK5z2LcKEdg16Yv4FFneEL1zg9ojd")
        await #expect(throws: BlockchairResponseError.self) {
            try await ZcashChain.default.scanner.getBalance(forToken: account, forAccount: account)
        }
    }

    // NOT A RECORDING: made-up values in the address dashboard's shape
    private static let documented = """
    {"data":{"t3Vz22vK5z2LcKEdg16Yv4FFneEL1zg9ojd":{"address":{"type":"pubkeyhash","balance":150000000,"transaction_count":2},\
    "transactions":[{"block_id":3000001,"hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","time":"2026-01-01 00:00:00","balance_change":-50000000},\
    {"block_id":3000000,"hash":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","time":"2025-12-31 23:00:00","balance_change":200000000}],"utxo":[]}},\
    "context":{"code":200,"state":3000010}}
    """

    /// One mapped transaction's facts, its existential opened: its amount's currency read as `C`
    private static func reading<C: CryptoContract>(
        _ transaction: some CryptoTransaction, as _: C.Type
    ) -> (hash: String, quantity: Int128, currency: C?, from: String?, to: String?, fee: Int128?, successful: Bool,
          timeStamp: Date) {
        (transaction.hash, transaction.amount.quantity, transaction.amount.currency as? C,
         transaction.fromContract?.address, transaction.toContract?.address, transaction.gasPrice?.quantity,
         transaction.successful, transaction.timeStamp)
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
