// SiaChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Sia:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct SiaChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(SiaChain.default.id == "sia:mainnet")
        #expect(SiaChain.default.id == SIA.Sia.chainId)
        let instance = try AssetInstance(validating: SiaChain.default.id + ":" + "shape")
        #expect(instance.chainId == SiaChain.default.id)
    }

    /// CAIP-2's shape: the namespace, 3 to 8 of `[-a-z0-9]`; the reference, 1 to 32 of `[-_a-zA-Z0-9]`
    @Test func theIdIsShapedAsCAIP2() {
        let parts = SiaChain.default.id.split(separator: ":")
        #expect(parts.count == 2)
        #expect((3...8).contains(parts[0].count))
        #expect(parts[0].allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") })
        #expect((1...32).contains(parts[1].count))
        #expect(parts[1].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
    }

    /// CAIP's registry holds no `sia` (read 2026-10-07), so the library owns the namespace in its own table
    @Test func theNamespaceIsTheLibrarys() {
        #expect(SIA.namespace == "sia")
        #expect(AssetRegistry.ownedNamespaces.contains(SIA.namespace))
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(SiaChain.default.mainContract.isChainToken)
        #expect(SiaChain.default.mainContract.address == "sc")
        #expect(AssetInstance(SiaChain.default.mainContract).id == SIA.Sia.sc.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(SiaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 24)
        #expect(SIA.Sia.sc.decimals == 24)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(SIA.Sia.sc))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(SiaChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == SIA.Sia.sc)
        #expect(declaration.symbol.text == "SC")
        #expect(declaration.tokenName == "Siacoin")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(SiaContract.Units.sc.divisorFromBase == Self.tenToThe(SIA.Sia.sc.decimals))
        #expect(SiaContract.Units.defaultDisplayUnits == .sc)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(SiaContract.Units.hasting.divisorFromBase == Self.tenToThe(0))
        #expect(SiaContract.Units.chainBaseUnits == .hasting)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as the chain writes it
    @Test(arguments: ["000000000000000000000000000000000000000000000000000000000000000089eb0d6a8a69", "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20a1b2c3d4e5f6"])
    func aWellFormedAddressIsKept(_ address: String) throws {
        #expect(try SiaChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["000000000000000000000000000000000000000000000000000000000000000089eb0d6a8a6", "000000000000000000000000000000000000000000000000000000000000000089eb0d6a8a690", "addr:000000000000000000000000000000000000000000000000000000000000000089eb0d6a8a69", "0000000000000000000000000000000000000000000000000000000000000000", "000000000000000000000000000000000000000000000000000000000000000089eb0d6a8a6g"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try SiaChain.default.contract(for: address) }
    }

    /// An address in another form the chain accepts is written in its canonical form
    @Test(arguments: [("000000000000000000000000000000000000000000000000000000000000000089EB0D6A8A69", "000000000000000000000000000000000000000000000000000000000000000089eb0d6a8a69")])
    func anAddressIsNormalizedByTheChain(_ given: String, _ canonical: String) throws {
        #expect(try SiaChain.default.contract(for: given).address == canonical)
        #expect(try AssetInstance(SiaChain.default.contract(for: given)).id == SiaChain.default.id + ":" + canonical)
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try SiaChain.default.contract(for: "000000000000000000000000000000000000000000000000000000000000000089eb0d6a8a69")
        let decoded: SiaContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == SiaChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(SiaChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? SiaContract)
        #expect(contract == SiaChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: SiaChain.default.id + ":" + "000000000000000000000000000000000000000000000000000000000000000089eb0d6a8a69")
        let contract = try #require(BlockChains.contract(of: account) as? SiaContract)
        #expect(contract.address == "000000000000000000000000000000000000000000000000000000000000000089eb0d6a8a69")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko names no Sia platform, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(SiaChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(SiaChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(SiaChain.default.scanner.userReadableName == "SiaScan")
        #expect(SiaScan.endPoint.absoluteString == "https://api.siascan.com")
    }

    /// The recorded balance of the void address, where burnt siacoins go: its unspent siacoins in hastings, at SC's
    /// declared 24
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: SiaScan.BalanceResponse = try CoinGeckoRecorded.data("Sia/balance.json").fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 10_517_066_763_574_034_269_136_917_794_384)
        #expect(amount.currency == SiaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 24)
    }

    /// The recorded events: three siafund claims paid to the void address, each its siacoin output in hastings
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let transactions = try SiaChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("Sia/events.json"))
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: SiaContract.self) }
        #expect(reads.map(\.quantity) == [
            7_860_443_679_163_131_911_904_479_550, 38_064_533_170_923_487_974_267_950_169,
            3_218_033_989_121_393_143_785_004_898
        ])
        #expect(reads.allSatisfy { $0.from == nil && $0.to == "000000000000000000000000000000000000000000000000000000000000000089eb0d6a8a69" && $0.type == "siafundClaim" && $0.successful })
        #expect(reads[0].hash == "5edc469a1f03464348374d3fc81eac1b7a0f0af8f2a3e5cf0e812a837af7d6c1")
        #expect(reads[0].timeStamp == (try Date("2026-07-16T15:51:41Z", strategy: .iso8601)))
    }

    /// NOT A RECORDING: an event of a kind not read throws, so the list is never answered short
    @Test func anEventOfAnotherKindIsNotRead() throws {
        let shaped = #"[{"id":"ab","index":{"height":1,"id":"00"},"confirmations":1,"type":"v2Transaction","data":{"siacoinInputs":[]},"maturityHeight":1,"timestamp":"2026-01-01T00:00:00Z","relevant":[]}]"#
        #expect(throws: SiaScanResponseError.self) { try SiaChain.default.scanner.loadTransactions(from: Data(shaped.utf8)) }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try SiaChain.default.contract(for: "000000000000000000000000000000000000000000000000000000000000000089eb0d6a8a69")
        let other = try SiaChain.default.contract(for: "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20a1b2c3d4e5f6")
        await #expect(throws: SiaScanResponseError.self) {
            try await SiaChain.default.scanner.getBalance(forToken: other, forAccount: account)
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
