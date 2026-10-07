// DashChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Dash:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No
/// network.
@Suite struct DashChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(DashChain.default.id == "bip122:00000ffd590b1485b3caadc19b22e637")
        #expect(DashChain.default.id == BIP122.Dash.chainId)
        let instance = try AssetInstance(validating: DashChain.default.id + ":" + "shape")
        #expect(instance.chainId == DashChain.default.id)
        #expect(DashChain.default.id.split(separator: ":").count == 2)
    }

    /// The bip122 form: 32 lower-case hex digits after `bip122:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = DashChain.default.id.dropFirst("bip122:".count)
        #expect(DashChain.default.id.hasPrefix("bip122:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(DashChain.default.mainContract.isChainToken)
        #expect(DashChain.default.mainContract.address == "dash")
        #expect(AssetInstance(DashChain.default.mainContract).id == BIP122.Dash.dash.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(DashChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(BIP122.Dash.dash.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(BIP122.Dash.dash))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(DashChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == BIP122.Dash.dash)
        #expect(declaration.symbol.text == "DASH")
        #expect(declaration.tokenName == "Dash")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(DashContract.Units.dash.divisorFromBase == Self.tenToThe(BIP122.Dash.dash.decimals))
        #expect(DashContract.Units.defaultDisplayUnits == .dash)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(DashContract.Units.duff.divisorFromBase == Self.tenToThe(0))
        #expect(DashContract.Units.chainBaseUnits == .duff)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh", "7SVyqiBykMKdoNuuf1AehnVxASmtdfqsFF"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try DashChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["xgtyuk76vhufw2it7uaihgndwxcf3j34wh", "Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34w", "yjPtiKh2uwk3bDutTEA2q9mCtXyiZRWn55", "16L5yRNPTuciSgXGHqYwn9N6NeoKqopAu", "DBcZSePDaMMduBMLymWHXhkE5ArFEvkagU"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try DashChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try DashChain.default.contract(for: "Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh")
        let decoded: DashContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == DashChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(DashChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? DashContract)
        #expect(contract == DashChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: DashChain.default.id + ":" + "Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh")
        let contract = try #require(BlockChains.contract(of: account) as? DashContract)
        #expect(contract.address == "Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's recorded platforms name none on Dash, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(DashChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(DashChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsBlockchairForTheChainReadWithNoUnwrap() {
        #expect(DashChain.default.scanner.userReadableName == "Blockchair")
        #expect(DashChain.default.scanner.slug == "dash")
    }

    /// Blockchair's recorded `/stats` lists the chain by its slug
    @Test func blockchairServesTheChain() throws {
        #expect(try BlockchairNoNetworkTests.servedSlugs().contains("dash"))
    }

    /// The recorded read of `Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh`: Blockchair refused it (430, the address read
    /// rate-limited by IP), and the
    /// refusal is thrown in its words
    @Test func theRecordedRefusalIsThrownInBlockchairsWords() throws {
        let response: Blockchair<DashContract>.DashboardResponse = try CoinGeckoRecorded.data("Dash/dashboards-address.json").fromJSON()
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
    /// read was refused): the balance in the chain's base unit, at DASH's declared 8
    @Test func aBalanceInTheDashboardsShapeIsTheCoinAtItsDecimals() throws {
        let response: Blockchair<DashContract>.DashboardResponse = try Data(Self.documented.utf8).fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 150_000_000)
        #expect(amount.currency == DashChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 8)
    }

    /// NOT A RECORDING, as above: a send and a receipt, each the size of the address's balance change
    @Test func transactionsInTheDashboardsShapeMapToTheCoin() throws {
        let transactions = try DashChain.default.scanner.loadTransactions(from: Data(Self.documented.utf8))
        try #require(transactions.count == 2)
        let reads = transactions.map { Self.reading($0, as: DashContract.self) }
        #expect(reads.map(\.quantity) == [50_000_000, 200_000_000])
        #expect(reads.map(\.from) == ["Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh", nil])
        #expect(reads.map(\.to) == [nil, "Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh"])
        #expect(reads.allSatisfy { $0.currency == DashChain.default.mainContract && $0.successful && $0.fee == nil })
        #expect(reads.map(\.hash) == [String(repeating: "a", count: 64), String(repeating: "b", count: 64)])
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: 1_767_225_600))
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try DashChain.default.contract(for: "Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh")
        await #expect(throws: BlockchairResponseError.self) {
            try await DashChain.default.scanner.getBalance(forToken: account, forAccount: account)
        }
    }

    // NOT A RECORDING: made-up values in the address dashboard's shape
    private static let documented = """
    {"data":{"Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh":{"address":{"type":"pubkeyhash","balance":150000000,"transaction_count":2},\
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
