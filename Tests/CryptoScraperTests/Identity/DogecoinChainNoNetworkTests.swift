// DogecoinChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Dogecoin:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No
/// network.
@Suite struct DogecoinChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(DogecoinChain.default.id == "bip122:1a91e3dace36e2be3bf030a65679fe82")
        #expect(DogecoinChain.default.id == BIP122.Dogecoin.chainId)
        let instance = try AssetInstance(validating: DogecoinChain.default.id + ":" + "shape")
        #expect(instance.chainId == DogecoinChain.default.id)
        #expect(DogecoinChain.default.id.split(separator: ":").count == 2)
    }

    /// The bip122 form: 32 lower-case hex digits after `bip122:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = DogecoinChain.default.id.dropFirst("bip122:".count)
        #expect(DogecoinChain.default.id.hasPrefix("bip122:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(DogecoinChain.default.mainContract.isChainToken)
        #expect(DogecoinChain.default.mainContract.address == "doge")
        #expect(AssetInstance(DogecoinChain.default.mainContract).id == BIP122.Dogecoin.doge.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(DogecoinChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(BIP122.Dogecoin.doge.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(BIP122.Dogecoin.doge))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(DogecoinChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == BIP122.Dogecoin.doge)
        #expect(declaration.symbol.text == "DOGE")
        #expect(declaration.tokenName == "Dogecoin")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(DogecoinContract.Units.doge.divisorFromBase == Self.tenToThe(BIP122.Dogecoin.doge.decimals))
        #expect(DogecoinContract.Units.defaultDisplayUnits == .doge)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(DogecoinContract.Units.koinu.divisorFromBase == Self.tenToThe(0))
        #expect(DogecoinContract.Units.chainBaseUnits == .koinu)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["DBcZSePDaMMduBMLymWHXhkE5ArFEvkagU", "9rXbkMyi1S6thykRoXAZcY8fwUKYsy6cXE"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try DogecoinChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["dbczsepdammdubmlymwhxhke5arfevkagu", "DBcZSePDaMMduBMLymWHXhkE5ArFEvkag", "16L5yRNPTuciSgXGHqYwn9N6NeoKqopAu", "LKKHMBjCU89fyFNgSRprDoD8Jb25N8uWvd", "doge1qqypqxpq9qcrsszg2pvxq6rs0zqg3yyc5dyg36p"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try DogecoinChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try DogecoinChain.default.contract(for: "DBcZSePDaMMduBMLymWHXhkE5ArFEvkagU")
        let decoded: DogecoinContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == DogecoinChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(DogecoinChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? DogecoinContract)
        #expect(contract == DogecoinChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: DogecoinChain.default.id + ":" + "DBcZSePDaMMduBMLymWHXhkE5ArFEvkagU")
        let contract = try #require(BlockChains.contract(of: account) as? DogecoinContract)
        #expect(contract.address == "DBcZSePDaMMduBMLymWHXhkE5ArFEvkagU")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's `drc-20` platform (native `dogecoin`) lists inscriptions, not contracts, as Bitcoin's `ordinals` is
    /// left out; `dogechain` is an EVM chain (2000): the table has no row for Dogecoin
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(DogecoinChain.default.id) == false)
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "drc-20", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "drc-20") == nil)
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "dogechain", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "dogechain") == nil)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(DogecoinChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsBlockchairForTheChainReadWithNoUnwrap() {
        #expect(DogecoinChain.default.scanner.userReadableName == "Blockchair")
        #expect(DogecoinChain.default.scanner.slug == "dogecoin")
    }

    /// Blockchair's recorded `/stats` lists the chain by its slug
    @Test func blockchairServesTheChain() throws {
        #expect(try BlockchairNoNetworkTests.servedSlugs().contains("dogecoin"))
    }

    /// The recorded read of `DBcZSePDaMMduBMLymWHXhkE5ArFEvkagU`: Blockchair refused it (430, the address read
    /// rate-limited by IP), and the
    /// refusal is thrown in its words
    @Test func theRecordedRefusalIsThrownInBlockchairsWords() throws {
        let response: Blockchair<DogecoinContract>.DashboardResponse = try CoinGeckoRecorded.data("Dogecoin/dashboards-address.json").fromJSON()
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
    /// read was refused): the balance in the chain's base unit, at DOGE's declared 8
    @Test func aBalanceInTheDashboardsShapeIsTheCoinAtItsDecimals() throws {
        let response: Blockchair<DogecoinContract>.DashboardResponse = try Data(Self.documented.utf8).fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 150_000_000)
        #expect(amount.currency == DogecoinChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 8)
    }

    /// NOT A RECORDING, as above: a send and a receipt, each the size of the address's balance change
    @Test func transactionsInTheDashboardsShapeMapToTheCoin() throws {
        let transactions = try DogecoinChain.default.scanner.loadTransactions(from: Data(Self.documented.utf8))
        try #require(transactions.count == 2)
        let reads = transactions.map { Self.reading($0, as: DogecoinContract.self) }
        #expect(reads.map(\.quantity) == [50_000_000, 200_000_000])
        #expect(reads.map(\.from) == ["DBcZSePDaMMduBMLymWHXhkE5ArFEvkagU", nil])
        #expect(reads.map(\.to) == [nil, "DBcZSePDaMMduBMLymWHXhkE5ArFEvkagU"])
        #expect(reads.allSatisfy { $0.currency == DogecoinChain.default.mainContract && $0.successful && $0.fee == nil })
        #expect(reads.map(\.hash) == [String(repeating: "a", count: 64), String(repeating: "b", count: 64)])
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: 1_767_225_600))
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try DogecoinChain.default.contract(for: "DBcZSePDaMMduBMLymWHXhkE5ArFEvkagU")
        await #expect(throws: BlockchairResponseError.self) {
            try await DogecoinChain.default.scanner.getBalance(forToken: account, forAccount: account)
        }
    }

    // NOT A RECORDING: made-up values in the address dashboard's shape
    private static let documented = """
    {"data":{"DBcZSePDaMMduBMLymWHXhkE5ArFEvkagU":{"address":{"type":"pubkeyhash","balance":150000000,"transaction_count":2},\
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
