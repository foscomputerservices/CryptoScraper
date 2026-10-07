// BitcoinCashChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Bitcoin Cash:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner. No
/// network.
@Suite struct BitcoinCashChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(BitcoinCashChain.default.id == "bip122:000000000000000000651ef99cb9fcbe")
        #expect(BitcoinCashChain.default.id == BIP122.BitcoinCash.chainId)
        let instance = try AssetInstance(validating: BitcoinCashChain.default.id + ":" + "shape")
        #expect(instance.chainId == BitcoinCashChain.default.id)
        #expect(BitcoinCashChain.default.id.split(separator: ":").count == 2)
    }

    /// The bip122 form: 32 lower-case hex digits after `bip122:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = BitcoinCashChain.default.id.dropFirst("bip122:".count)
        #expect(BitcoinCashChain.default.id.hasPrefix("bip122:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(BitcoinCashChain.default.mainContract.isChainToken)
        #expect(BitcoinCashChain.default.mainContract.address == "bch")
        #expect(AssetInstance(BitcoinCashChain.default.mainContract).id == BIP122.BitcoinCash.bch.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(BitcoinCashChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(BIP122.BitcoinCash.bch.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(BIP122.BitcoinCash.bch))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(BitcoinCashChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == BIP122.BitcoinCash.bch)
        #expect(declaration.symbol.text == "BCH")
        #expect(declaration.tokenName == "Bitcoin Cash")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(BitcoinCashContract.Units.bch.divisorFromBase == Self.tenToThe(BIP122.BitcoinCash.bch.decimals))
        #expect(BitcoinCashContract.Units.defaultDisplayUnits == .bch)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(BitcoinCashContract.Units.satoshi.divisorFromBase == Self.tenToThe(0))
        #expect(BitcoinCashContract.Units.chainBaseUnits == .satoshi)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a", "1BpEi6DfDAUFd7GtittLSdBeYJvcoaVggu", "31nM1WuowNDzocNxPPW9NQWJEtwWpjfcLj"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try BitcoinCashChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["ecash:qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a", "bchtest:qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a", "Bitcoincash:qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a", "bitcoincash:qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6", "bitcoincash:zpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a", "bitcoincash:qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6b1", "bitcoincash:", "LKKHMBjCU89fyFNgSRprDoD8Jb25N8uWvd"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try BitcoinCashChain.default.contract(for: address) }
    }

    /// CashAddr is written all in lower or all in upper case, lower case its canonical form; CAIP-10's account holds no
    /// colon, so the address is the CashAddr body alone, its `bitcoincash:` prefix dropped (as Conflux's `cfx:` is)
    @Test func anAddressIsNormalizedByTheChain() throws {
        #expect(try BitcoinCashChain.default.contract(for: "bitcoincash:qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a").address == "qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a")
        #expect(try BitcoinCashChain.default.contract(for: "BITCOINCASH:QPM2QSZNHKS23Z7629MMS6S4CWEF74VCWVY22GDX6A").address == "qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a")
        #expect(try BitcoinCashChain.default.contract(for: "QPM2QSZNHKS23Z7629MMS6S4CWEF74VCWVY22GDX6A").address == "qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try BitcoinCashChain.default.contract(for: "qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a")
        let decoded: BitcoinCashContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == BitcoinCashChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(BitcoinCashChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? BitcoinCashContract)
        #expect(contract == BitcoinCashChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: BitcoinCashChain.default.id + ":" + "qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a")
        let contract = try #require(BlockChains.contract(of: account) as? BitcoinCashContract)
        #expect(contract.address == "qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's `bitcoin-cash` platform lists Simple Ledger Protocol tokens, by token ids, not contracts, as
    /// Bitcoin's `ordinals` is left out; `smartbch` is an EVM chain (10000): the table has no row for Bitcoin Cash
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(BitcoinCashChain.default.id) == false)
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "bitcoin-cash", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "bitcoin-cash") == nil)
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "smartbch", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "smartbch") == nil)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(BitcoinCashChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsBlockchairForTheChainReadWithNoUnwrap() {
        #expect(BitcoinCashChain.default.scanner.userReadableName == "Blockchair")
        #expect(BitcoinCashChain.default.scanner.slug == "bitcoin-cash")
    }

    /// Blockchair's recorded `/stats` lists the chain by its slug
    @Test func blockchairServesTheChain() throws {
        #expect(try BlockchairNoNetworkTests.servedSlugs().contains("bitcoin-cash"))
    }

    /// The recorded read of `bitcoincash:qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a`: Blockchair refused it (430, the
    /// address read rate-limited by IP), and the
    /// refusal is thrown in its words
    @Test func theRecordedRefusalIsThrownInBlockchairsWords() throws {
        let response: Blockchair<BitcoinCashContract>.DashboardResponse = try CoinGeckoRecorded.data("BitcoinCash/dashboards-address.json").fromJSON()
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
    /// read was refused): the balance in the chain's base unit, at BCH's declared 8
    @Test func aBalanceInTheDashboardsShapeIsTheCoinAtItsDecimals() throws {
        let response: Blockchair<BitcoinCashContract>.DashboardResponse = try Data(Self.documented.utf8).fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 150_000_000)
        #expect(amount.currency == BitcoinCashChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 8)
    }

    /// NOT A RECORDING, as above: a send and a receipt, each the size of the address's balance change
    @Test func transactionsInTheDashboardsShapeMapToTheCoin() throws {
        let transactions = try BitcoinCashChain.default.scanner.loadTransactions(from: Data(Self.documented.utf8))
        try #require(transactions.count == 2)
        let reads = transactions.map { Self.reading($0, as: BitcoinCashContract.self) }
        #expect(reads.map(\.quantity) == [50_000_000, 200_000_000])
        #expect(reads.map(\.from) == ["qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a", nil])
        #expect(reads.map(\.to) == [nil, "qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a"])
        #expect(reads.allSatisfy { $0.currency == BitcoinCashChain.default.mainContract && $0.successful && $0.fee == nil })
        #expect(reads.map(\.hash) == [String(repeating: "a", count: 64), String(repeating: "b", count: 64)])
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: 1_767_225_600))
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try BitcoinCashChain.default.contract(for: "qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a")
        await #expect(throws: BlockchairResponseError.self) {
            try await BitcoinCashChain.default.scanner.getBalance(forToken: account, forAccount: account)
        }
    }

    /// Blockchair is asked for a CashAddr with its prefix put back, a legacy address as given
    @Test func blockchairIsAskedForTheCashAddrWithItsPrefix() throws {
        let cashAddr = try BitcoinCashChain.default.contract(for: "qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a")
        let legacy = try BitcoinCashChain.default.contract(for: "1BpEi6DfDAUFd7GtittLSdBeYJvcoaVggu")
        #expect(BitcoinCashChain.default.scanner.apiAddress(cashAddr) == "bitcoincash:qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a")
        #expect(BitcoinCashChain.default.scanner.apiAddress(legacy) == "1BpEi6DfDAUFd7GtittLSdBeYJvcoaVggu")
    }

    // NOT A RECORDING: made-up values in the address dashboard's shape
    private static let documented = """
    {"data":{"bitcoincash:qpm2qsznhks23z7629mms6s4cwef74vcwvy22gdx6a":{"address":{"type":"pubkeyhash","balance":150000000,"transaction_count":2},\
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
