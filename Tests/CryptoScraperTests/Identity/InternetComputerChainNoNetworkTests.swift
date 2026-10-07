// InternetComputerChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Internet Computer:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct InternetComputerChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(InternetComputerChain.default.id == "icp:mainnet")
        #expect(InternetComputerChain.default.id == ICP.InternetComputer.chainId)
        let instance = try AssetInstance(validating: InternetComputerChain.default.id + ":" + "shape")
        #expect(instance.chainId == InternetComputerChain.default.id)
    }

    /// CAIP-2's shape: the namespace, 3 to 8 of `[-a-z0-9]`; the reference, 1 to 32 of `[-_a-zA-Z0-9]`
    @Test func theIdIsShapedAsCAIP2() {
        let parts = InternetComputerChain.default.id.split(separator: ":")
        #expect(parts.count == 2)
        #expect((3...8).contains(parts[0].count))
        #expect(parts[0].allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") })
        #expect((1...32).contains(parts[1].count))
        #expect(parts[1].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
    }

    /// CAIP's registry holds no `icp` (read 2026-10-07), so the library owns the namespace in its own table
    @Test func theNamespaceIsTheLibrarys() {
        #expect(ICP.namespace == "icp")
        #expect(AssetRegistry.ownedNamespaces.contains(ICP.namespace))
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(InternetComputerChain.default.mainContract.isChainToken)
        #expect(InternetComputerChain.default.mainContract.address == "icp")
        #expect(AssetInstance(InternetComputerChain.default.mainContract).id == ICP.InternetComputer.icp.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(InternetComputerChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(ICP.InternetComputer.icp.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(ICP.InternetComputer.icp))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(InternetComputerChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == ICP.InternetComputer.icp)
        #expect(declaration.symbol.text == "ICP")
        #expect(declaration.tokenName == "Internet Computer")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(InternetComputerContract.Units.icp.divisorFromBase == Self.tenToThe(ICP.InternetComputer.icp.decimals))
        #expect(InternetComputerContract.Units.defaultDisplayUnits == .icp)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(InternetComputerContract.Units.e8s.divisorFromBase == Self.tenToThe(0))
        #expect(InternetComputerContract.Units.chainBaseUnits == .e8s)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as the chain writes it
    @Test(arguments: ["082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5", "883eef7c44be51afe4a4420d4df4beff708f3cf2f5de5efcc9f58680bb0f3690"])
    func aWellFormedAddressIsKept(_ address: String) throws {
        #expect(try InternetComputerChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b", "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b50", "0x2ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5", "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2bg", "near"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try InternetComputerChain.default.contract(for: address) }
    }

    /// An address in another form the chain accepts is written in its canonical form
    @Test(arguments: [("082ECF2E3F647AC600F43F38A68342FBA5B8E68B085F02592B77F39808A8D2B5", "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5")])
    func anAddressIsNormalizedByTheChain(_ given: String, _ canonical: String) throws {
        #expect(try InternetComputerChain.default.contract(for: given).address == canonical)
        #expect(try AssetInstance(InternetComputerChain.default.contract(for: given)).id == InternetComputerChain.default.id + ":" + canonical)
    }

    /// A principal names a canister or a user, not an account: it is refused with its own reason
    @Test(arguments: ["rrkah-fqaaa-aaaaa-aaaaq-cai", "ryjl3-tyaaa-aaaaa-aaaba-cai"])
    func aPrincipalIsRefusedAsNotAnAccount(_ principal: String) {
        #expect(throws: BlockChainError.notAnAccount(principal)) { try InternetComputerChain.default.contract(for: principal) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try InternetComputerChain.default.contract(for: "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5")
        let decoded: InternetComputerContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == InternetComputerChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(InternetComputerChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? InternetComputerContract)
        #expect(contract == InternetComputerChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: InternetComputerChain.default.id + ":" + "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5")
        let contract = try #require(BlockChains.contract(of: account) as? InternetComputerContract)
        #expect(contract.address == "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "internet-computer", by: .coinGecko) == InternetComputerChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "internet-computer")?.chainId == InternetComputerChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(InternetComputerChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(InternetComputerChain.default.scanner.userReadableName == "ICP Rosetta")
        #expect(ICPRosetta.endPoint.absoluteString == "https://rosetta-api.internetcomputer.org")
        #expect(ICPRosetta.networkIdentifier["network"] == "00000000000000020101")
    }

    /// The recorded balance of the NNS governance canister's default account (its identifier by the ledger's rule):
    /// none, in ICP at 8, as the answer itself states
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: ICPRosetta.BalanceResponse = try CoinGeckoRecorded.data("InternetComputer/balance.json").fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 0)
        #expect(amount.currency == InternetComputerChain.default.mainContract)
        #expect(response.balances.first?.currency.decimals == 8)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 8)
    }

    /// NOT A RECORDING: a balance in the shape Rosetta answers, its value made up, read in e8s; another currency is
    /// refused
    @Test func aBalanceInTheAnswersShapeIsItsE8s() throws {
        let shaped = #"{"block_identifier":{"index":1,"hash":"00"},"balances":[{"value":"123456789","currency":{"symbol":"ICP","decimals":8}}]}"#
        let response: ICPRosetta.BalanceResponse = try Data(shaped.utf8).fromJSON()
        #expect(try response.amount().quantity == 123_456_789)
        let other = #"{"block_identifier":{"index":1,"hash":"00"},"balances":[{"value":"1","currency":{"symbol":"ckBTC","decimals":8}}]}"#
        let refused: ICPRosetta.BalanceResponse = try Data(other.utf8).fromJSON()
        #expect(throws: ICPRosettaResponseError.self) { try refused.amount() }
    }

    /// The recorded search: three transfers of 0 e8s to the account, each fee 10,000 e8s on its sender
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let account = try InternetComputerChain.default.contract(for: "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5")
        let transactions = try InternetComputerChain.default.scanner.loadTransactions(
            from: CoinGeckoRecorded.data("InternetComputer/search-transactions.json"), forAccount: account
        )
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: InternetComputerContract.self) }
        #expect(reads.map(\.quantity) == [0, 0, 0])
        #expect(reads.map(\.fee) == [10000, 10000, 10000])
        #expect(reads.map(\.from) == [
            "c1a4547130f8b78a9e1a8f5a4c4f3ad3209f3930a34163781ad203ef210ba746",
            "fdf8b5885c9a6c9a48a400cced4fc2cf19a737c939889694691ef0bddedb66e7",
            "cb4263252c0d8e4d88b22fdd0ccfc2d3a4aba0928b9a930ae601942b50ac5f93"
        ])
        #expect(reads.allSatisfy { $0.to == "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5" && $0.successful && $0.currency == InternetComputerChain.default.mainContract })
        #expect(reads[0].hash == "8986ab71c71224281d0eabf38d32d6e7ace226ef96edb241124f3cc87d58f216")
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: TimeInterval(1_788_788_175_936) / 1000))
        #expect(try InternetComputerChain.default.contract(for: reads[0].from!).address == reads[0].from)
    }

    /// NOT A RECORDING: a transfer in the search's shape, its values made up: the account sent 5,000,000 e8s
    @Test func aSendInTheAnswersShapeMapsFromTheAccount() throws {
        let account = try InternetComputerChain.default.contract(for: "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5")
        let other = "c1a4547130f8b78a9e1a8f5a4c4f3ad3209f3930a34163781ad203ef210ba746"
        let shaped = """
        {"transactions":[{"block_identifier":{"index":1,"hash":"00"},"transaction":{"transaction_identifier":{"hash":"ab"},
        "operations":[
        {"operation_identifier":{"index":0},"type":"TRANSACTION","status":"COMPLETED","account":{"address":"082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5"},"amount":{"value":"-5000000","currency":{"symbol":"ICP","decimals":8}}},
        {"operation_identifier":{"index":1},"type":"TRANSACTION","status":"COMPLETED","account":{"address":"\(other)"},"amount":{"value":"5000000","currency":{"symbol":"ICP","decimals":8}}},
        {"operation_identifier":{"index":2},"type":"FEE","status":"COMPLETED","account":{"address":"082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5"},"amount":{"value":"-10000","currency":{"symbol":"ICP","decimals":8}}}],
        "metadata":{"block_height":1,"memo":0,"timestamp":1000000000000000000}}}],"total_count":1}
        """
        let transactions = try InternetComputerChain.default.scanner.loadTransactions(from: Data(shaped.utf8), forAccount: account)
        let first = try #require(transactions.first)
        let read = Self.reading(first, as: InternetComputerContract.self)
        #expect(read.quantity == 5_000_000)
        #expect(read.fee == 10000)
        #expect(read.from == account.address)
        #expect(read.to == other)
    }

    /// A Rosetta search answer does not name the account it was asked about, so it is read only for an account
    @Test func transactionsAreNotReadWithoutTheirAccount() throws {
        #expect(throws: ICPRosettaResponseError.self) { try InternetComputerChain.default.scanner.loadTransactions(from: Data("{}".utf8)) }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try InternetComputerChain.default.contract(for: "082ecf2e3f647ac600f43f38a68342fba5b8e68b085f02592b77f39808a8d2b5")
        let other = try InternetComputerChain.default.contract(for: "883eef7c44be51afe4a4420d4df4beff708f3cf2f5de5efcc9f58680bb0f3690")
        await #expect(throws: ICPRosettaResponseError.self) {
            try await InternetComputerChain.default.scanner.getBalance(forToken: other, forAccount: account)
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
