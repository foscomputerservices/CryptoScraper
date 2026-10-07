// IotaChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for IOTA: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct IotaChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(IotaChain.default.id == "iota:mainnet")
        #expect(IotaChain.default.id == IOTA.Iota.chainId)
        let instance = try AssetInstance(validating: IotaChain.default.id + ":" + "shape")
        #expect(instance.chainId == IotaChain.default.id)
        #expect(IotaChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(IotaChain.default.mainContract.isChainToken)
        #expect(IotaChain.default.mainContract.address == "iota")
        #expect(AssetInstance(IotaChain.default.mainContract).id == IOTA.Iota.iota.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(IotaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 9)
        #expect(IOTA.Iota.iota.decimals == 9)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(IOTA.Iota.iota))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(IotaChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == IOTA.Iota.iota)
        #expect(declaration.symbol.text == "IOTA")
        #expect(declaration.tokenName == "IOTA")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(IotaContract.Units.iota.divisorFromBase == Self.tenToThe(IOTA.Iota.iota.decimals))
        #expect(IotaContract.Units.defaultDisplayUnits == .iota)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(IotaContract.Units.nano.divisorFromBase == Self.tenToThe(0))
        #expect(IotaContract.Units.chainBaseUnits == .nano)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try IotaChain.default.contract(for: "0x51ceab2edc89f74730e683ebee65578cb3bc9237ba6fca019438a9737cf156ae").address == "0x51ceab2edc89f74730e683ebee65578cb3bc9237ba6fca019438a9737cf156ae")
    }

    @Test(arguments: ["0x2", "iota1qpszqzadsym6wpppd6z037dvlejmjuke7s24hm95s9fg9vpua7vluaw60xu", "0x51ceab2edc89f74730e683ebee65578cb3bc9237ba6fca019438a9737cf156ae0", "0x51ceab2edc89f74730e683ebee65578cb3bc9237ba6fca019438a9737cf156ae::coin", "0x00000000000000000000000000000000000000000000000000000000000000ab::cert::CERT"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try IotaChain.default.contract(for: address) }
    }

    /// An address is a number, so its hex is lower-cased
    @Test func anAddressIsNormalizedByTheChain() throws {
        #expect(try IotaChain.default.contract(for: "0x51CEAB2EDC89F74730E683EBEE65578CB3BC9237BA6FCA019438A9737CF156AE").address == "0x51ceab2edc89f74730e683ebee65578cb3bc9237ba6fca019438a9737cf156ae")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try IotaChain.default.contract(for: "0x51ceab2edc89f74730e683ebee65578cb3bc9237ba6fca019438a9737cf156ae")
        let decoded: IotaContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == IotaChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(IotaChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? IotaContract)
        #expect(contract == IotaChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: IotaChain.default.id + ":" + "0x51ceab2edc89f74730e683ebee65578cb3bc9237ba6fca019438a9737cf156ae")
        let contract = try #require(BlockChains.contract(of: account) as? IotaContract)
        #expect(contract.address == "0x51ceab2edc89f74730e683ebee65578cb3bc9237ba6fca019438a9737cf156ae")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "iota", by: .coinGecko) == IotaChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "iota")?.chainId == IotaChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(IotaChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(IotaChain.default.scanner.userReadableName == "IOTA RPC")
    }

    /// The recorded docs' example address: no IOTA, 0 nanos, of the coin type `0x2::iota::IOTA`
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: IotaRPC.Response<IotaRPC.BalanceResponse> = try CoinGeckoRecorded.data("IOTA/iotax_getBalance.json").fromJSON()
        let amount = try response.value().amount()
        #expect(amount.quantity == 0)
        #expect(amount.currency == IotaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 9)
    }

    /// The recorded transaction blocks to the docs' example address are none
    @Test func theRecordedTransactionsAreEmpty() throws {
        #expect(try IotaChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("IOTA/iotax_queryTransactionBlocks.json")).isEmpty)
    }

    /// NOT A RECORDING: `iotax_queryTransactionBlocks` in the shape IOTA's API reference gives, its values made up
    /// (the recorded answer is empty), one block sending 1.5 IOTA, to show the mapping: the sender's IOTA change, its
    /// fee its computation and storage less the rebate, at IOTA's declared 9
    @Test func aBlockInTheDocumentedShapeMapsToTheCoin() throws {
        let sender = "0x" + String(repeating: "a", count: 64)
        let receiver = "0x" + String(repeating: "b", count: 64)
        let documented = """
        {"jsonrpc":"2.0","id":1,"result":{"data":[{"digest":"MadeUpDigest","timestampMs":"1791000000000","transaction":{"data":{"sender":"\(sender)"}},"effects":{"status":{"status":"success"},"gasUsed":{"computationCost":"1000000","storageCost":"2000000","storageRebate":"500000"}},"balanceChanges":[{"owner":{"AddressOwner":"\(sender)"},"coinType":"0x2::iota::IOTA","amount":"-1502500000"},{"owner":{"AddressOwner":"\(receiver)"},"coinType":"0x2::iota::IOTA","amount":"1500000000"},{"owner":"Immutable","coinType":"0x2::iota::IOTA","amount":"0"}]}],"nextCursor":null,"hasNextPage":false}}
        """
        let transactions = try IotaChain.default.scanner.loadTransactions(from: Data(documented.utf8))
        try #require(transactions.count == 1)
        let read = Self.reading(transactions[0], as: IotaContract.self)
        #expect(read.currency == IotaChain.default.mainContract)
        #expect(read.quantity == 1_502_500_000)
        #expect(read.fee == 2_500_000)
        #expect(read.from == sender && read.to == nil && read.successful)
        #expect(read.timeStamp == Date(timeIntervalSince1970: 1_791_000_000))
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try IotaChain.default.contract(for: "0x51ceab2edc89f74730e683ebee65578cb3bc9237ba6fca019438a9737cf156ae")
        await #expect(throws: IotaRPCResponseError.self) {
            try await IotaChain.default.scanner.getBalance(forToken: account, forAccount: account)
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
