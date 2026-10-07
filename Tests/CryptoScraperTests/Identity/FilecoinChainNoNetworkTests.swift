// FilecoinChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Filecoin: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct FilecoinChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(FilecoinChain.default.id == "fil:f")
        #expect(FilecoinChain.default.id == FIL.Filecoin.chainId)
        let instance = try AssetInstance(validating: FilecoinChain.default.id + ":" + "shape")
        #expect(instance.chainId == FilecoinChain.default.id)
        #expect(FilecoinChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(FilecoinChain.default.mainContract.isChainToken)
        #expect(FilecoinChain.default.mainContract.address == "fil")
        #expect(AssetInstance(FilecoinChain.default.mainContract).id == FIL.Filecoin.fil.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(FilecoinChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 18)
        #expect(FIL.Filecoin.fil.decimals == 18)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(FIL.Filecoin.fil))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(FilecoinChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == FIL.Filecoin.fil)
        #expect(declaration.symbol.text == "FIL")
        #expect(declaration.tokenName == "Filecoin")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(FilecoinContract.Units.fil.divisorFromBase == Self.tenToThe(FIL.Filecoin.fil.decimals))
        #expect(FilecoinContract.Units.defaultDisplayUnits == .fil)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(FilecoinContract.Units.attofil.divisorFromBase == Self.tenToThe(0))
        #expect(FilecoinContract.Units.chainBaseUnits == .attofil)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try FilecoinChain.default.contract(for: "f1inl5pymyb6j4nehhttl4vd5cnbvtxamyox7fugy").address == "f1inl5pymyb6j4nehhttl4vd5cnbvtxamyox7fugy")
    }

    @Test(arguments: ["t1inl5pymyb6j4nehhttl4vd5cnbvtxamyox7fugy", "F1INL5PYMYB6J4NEHHTTL4VD5CNBVTXAMYOX7FUGY", "f1inl5pymyb6j4nehhttl4vd5cnbvtxamyox7fug", "f0x99", "0x00000000000000000000000000000000000000a1"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try FilecoinChain.default.contract(for: address) }
    }

    /// An actor id and a delegated address are Filecoin mainnet addresses too
    @Test(arguments: ["f099", "f05", "f410fkkld55ioe7qg24wvt7fu6pbknb56ht7pt4zamxa"])
    func anActorIdOrADelegatedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try FilecoinChain.default.contract(for: address).address == address)
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try FilecoinChain.default.contract(for: "f1inl5pymyb6j4nehhttl4vd5cnbvtxamyox7fugy")
        let decoded: FilecoinContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == FilecoinChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(FilecoinChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? FilecoinContract)
        #expect(contract == FilecoinChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: FilecoinChain.default.id + ":" + "f1inl5pymyb6j4nehhttl4vd5cnbvtxamyox7fugy")
        let contract = try #require(BlockChains.contract(of: account) as? FilecoinContract)
        #expect(contract.address == "f1inl5pymyb6j4nehhttl4vd5cnbvtxamyox7fugy")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's `filecoin` platform states chain 314, Filecoin's EVM, whose tokens are written as EVM addresses: it
    /// is not this chain, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(FilecoinChain.default.id) == false)
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "filecoin", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "filecoin") == nil)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(FilecoinChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(FilecoinChain.default.scanner.userReadableName == "Filfox")
    }

    /// The recorded burn account `f099`: 42,992,195.750824555071026522 FIL in attoFIL, at FIL's declared 18
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: Filfox.AddressResponse = try CoinGeckoRecorded.data("Filecoin/address-f099.json").fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 42_992_195_750_824_555_071_026_522)
        #expect(amount.currency == FilecoinChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 18)
    }

    /// The recorded messages to `f099`: three `Send`s of no FIL, each with exit code 0
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let transactions = try FilecoinChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("Filecoin/messages-f099.json"))
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: FilecoinContract.self) }
        #expect(reads.map(\.quantity) == [0, 0, 0])
        #expect(reads.allSatisfy { $0.currency == FilecoinChain.default.mainContract && $0.successful && $0.fee == nil })
        #expect(reads.allSatisfy { $0.to == "f099" && $0.type == "Send" })
        #expect(reads[0].from == "f1inl5pymyb6j4nehhttl4vd5cnbvtxamyox7fugy")
        #expect(reads[0].hash == "bafy2bzacecetupvk6obbvwdkdvbs5vchzbyqkemdspr2ur7egog2capzntwp6")
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: 1_776_125_220))
    }

    /// A message's value is read by its digits, as attoFIL
    @Test func aMessagesValueIsItsAttoFIL() throws {
        let answer = """
        {"messages":[{"cid":"bafy-made-up","timestamp":1,"from":"f1inl5pymyb6j4nehhttl4vd5cnbvtxamyox7fugy","to":"f099","value":"1500000000000000000","method":"Send","receipt":{"exitCode":1}}]}
        """
        let transactions = try FilecoinChain.default.scanner.loadTransactions(from: Data(answer.utf8))
        try #require(transactions.count == 1)
        let read = Self.reading(transactions[0], as: FilecoinContract.self)
        #expect(read.quantity == 1_500_000_000_000_000_000)
        #expect(!read.successful)
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try FilecoinChain.default.contract(for: "f099")
        await #expect(throws: FilfoxResponseError.self) {
            try await FilecoinChain.default.scanner.getBalance(forToken: account, forAccount: account)
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
