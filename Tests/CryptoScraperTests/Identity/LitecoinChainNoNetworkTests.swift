// LitecoinChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Litecoin:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No
/// network.
@Suite struct LitecoinChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(LitecoinChain.default.id == "bip122:12a765e31ffd4059bada1e25190f6e98")
        #expect(LitecoinChain.default.id == BIP122.Litecoin.chainId)
        let instance = try AssetInstance(validating: LitecoinChain.default.id + ":" + "shape")
        #expect(instance.chainId == LitecoinChain.default.id)
        #expect(LitecoinChain.default.id.split(separator: ":").count == 2)
    }

    /// The bip122 form: 32 lower-case hex digits after `bip122:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = LitecoinChain.default.id.dropFirst("bip122:".count)
        #expect(LitecoinChain.default.id.hasPrefix("bip122:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(LitecoinChain.default.mainContract.isChainToken)
        #expect(LitecoinChain.default.mainContract.address == "ltc")
        #expect(AssetInstance(LitecoinChain.default.mainContract).id == BIP122.Litecoin.ltc.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(LitecoinChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(BIP122.Litecoin.ltc.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(BIP122.Litecoin.ltc))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(LitecoinChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == BIP122.Litecoin.ltc)
        #expect(declaration.symbol.text == "LTC")
        #expect(declaration.tokenName == "Litecoin")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(LitecoinContract.Units.ltc.divisorFromBase == Self.tenToThe(BIP122.Litecoin.ltc.decimals))
        #expect(LitecoinContract.Units.defaultDisplayUnits == .ltc)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(LitecoinContract.Units.litoshi.divisorFromBase == Self.tenToThe(0))
        #expect(LitecoinContract.Units.chainBaseUnits == .litoshi)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["ltc1q8c6fshw2dlwun7ekn9qwf37cu2rn755u9ym7p0", "LKKHMBjCU89fyFNgSRprDoD8Jb25N8uWvd", "M7zVKQKmtV5Rc7erVGVVC3khZbXxsS5HEX", "31nM1WuowNDzocNxPPW9NQWJEtwWpjfcLj", "ltc1pqqqsyqcyq5rqwzqfpg9scrgwpugpzysnzs23v9ccrydpk8qarc0sts9tf8"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try LitecoinChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["LTC1Q8C6FSHW2DLWUN7EKN9QWF37CU2RN755U9YM7P0", "ltc1q8c6fshw2dlwun7ekn9qwf37cu2rn755u9ym7p", "bc1qwz2lhc40s8ty3l5jg3plpve3y3l82x9l42q7fk", "16L5yRNPTuciSgXGHqYwn9N6NeoKqopAu", "LKKHMBjCU89fyFNgSRprDoD8Jb25N8uWv0", "Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try LitecoinChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try LitecoinChain.default.contract(for: "ltc1q8c6fshw2dlwun7ekn9qwf37cu2rn755u9ym7p0")
        let decoded: LitecoinContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == LitecoinChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(LitecoinChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? LitecoinContract)
        #expect(contract == LitecoinChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: LitecoinChain.default.id + ":" + "ltc1q8c6fshw2dlwun7ekn9qwf37cu2rn755u9ym7p0")
        let contract = try #require(BlockChains.contract(of: account) as? LitecoinContract)
        #expect(contract.address == "ltc1q8c6fshw2dlwun7ekn9qwf37cu2rn755u9ym7p0")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's recorded platforms name none on Litecoin, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(LitecoinChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(LitecoinChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsBlockchairForTheChainReadWithNoUnwrap() {
        #expect(LitecoinChain.default.scanner.userReadableName == "Blockchair")
        #expect(LitecoinChain.default.scanner.slug == "litecoin")
    }

    /// Blockchair's recorded `/stats` lists the chain by its slug
    @Test func blockchairServesTheChain() throws {
        #expect(try BlockchairNoNetworkTests.servedSlugs().contains("litecoin"))
    }

    /// The recorded read of `ltc1q8c6fshw2dlwun7ekn9qwf37cu2rn755u9ym7p0`: Blockchair refused it (430, the address read
    /// rate-limited by IP), and the
    /// refusal is thrown in its words
    @Test func theRecordedRefusalIsThrownInBlockchairsWords() throws {
        let response: Blockchair<LitecoinContract>.DashboardResponse = try CoinGeckoRecorded.data("Litecoin/dashboards-address.json").fromJSON()
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
    /// read was refused): the balance in the chain's base unit, at LTC's declared 8
    @Test func aBalanceInTheDashboardsShapeIsTheCoinAtItsDecimals() throws {
        let response: Blockchair<LitecoinContract>.DashboardResponse = try Data(Self.documented.utf8).fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 150_000_000)
        #expect(amount.currency == LitecoinChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 8)
    }

    /// NOT A RECORDING, as above: a send and a receipt, each the size of the address's balance change
    @Test func transactionsInTheDashboardsShapeMapToTheCoin() throws {
        let transactions = try LitecoinChain.default.scanner.loadTransactions(from: Data(Self.documented.utf8))
        try #require(transactions.count == 2)
        let reads = transactions.map { Self.reading($0, as: LitecoinContract.self) }
        #expect(reads.map(\.quantity) == [50_000_000, 200_000_000])
        #expect(reads.map(\.from) == ["ltc1q8c6fshw2dlwun7ekn9qwf37cu2rn755u9ym7p0", nil])
        #expect(reads.map(\.to) == [nil, "ltc1q8c6fshw2dlwun7ekn9qwf37cu2rn755u9ym7p0"])
        #expect(reads.allSatisfy { $0.currency == LitecoinChain.default.mainContract && $0.successful && $0.fee == nil })
        #expect(reads.map(\.hash) == [String(repeating: "a", count: 64), String(repeating: "b", count: 64)])
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: 1_767_225_600))
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try LitecoinChain.default.contract(for: "ltc1q8c6fshw2dlwun7ekn9qwf37cu2rn755u9ym7p0")
        await #expect(throws: BlockchairResponseError.self) {
            try await LitecoinChain.default.scanner.getBalance(forToken: account, forAccount: account)
        }
    }

    // NOT A RECORDING: made-up values in the address dashboard's shape
    private static let documented = """
    {"data":{"ltc1q8c6fshw2dlwun7ekn9qwf37cu2rn755u9ym7p0":{"address":{"type":"pubkeyhash","balance":150000000,"transaction_count":2},\
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
