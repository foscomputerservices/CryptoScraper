// CardanoChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Cardano:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct CardanoChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(CardanoChain.default.id == "cip34:1-764824073")
        #expect(CardanoChain.default.id == CIP34.Cardano.chainId)
        let instance = try AssetInstance(validating: CardanoChain.default.id + ":" + "shape")
        #expect(instance.chainId == CardanoChain.default.id)
    }

    /// CAIP-2's shape: the namespace, 3 to 8 of `[-a-z0-9]`; the reference, 1 to 32 of `[-_a-zA-Z0-9]`
    @Test func theIdIsShapedAsCAIP2() {
        let parts = CardanoChain.default.id.split(separator: ":")
        #expect(parts.count == 2)
        #expect((3...8).contains(parts[0].count))
        #expect(parts[0].allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") })
        #expect((1...32).contains(parts[1].count))
        #expect(parts[1].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
    }

    /// CAIP's registry holds no `cip34` (read 2026-10-07), so the library owns the namespace in its own table
    @Test func theNamespaceIsTheLibrarys() {
        #expect(CIP34.namespace == "cip34")
        #expect(AssetRegistry.ownedNamespaces.contains(CIP34.namespace))
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(CardanoChain.default.mainContract.isChainToken)
        #expect(CardanoChain.default.mainContract.address == "ada")
        #expect(AssetInstance(CardanoChain.default.mainContract).id == CIP34.Cardano.ada.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(CardanoChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 6)
        #expect(CIP34.Cardano.ada.decimals == 6)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(CIP34.Cardano.ada))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(CardanoChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == CIP34.Cardano.ada)
        #expect(declaration.symbol.text == "ADA")
        #expect(declaration.tokenName == "Cardano")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(CardanoContract.Units.ada.divisorFromBase == Self.tenToThe(CIP34.Cardano.ada.decimals))
        #expect(CardanoContract.Units.defaultDisplayUnits == .ada)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(CardanoContract.Units.lovelace.divisorFromBase == Self.tenToThe(0))
        #expect(CardanoContract.Units.chainBaseUnits == .lovelace)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as the chain writes it
    @Test(arguments: ["addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3n0d3vllmyqwsx5wktcd8cc3sq835lu7drv2xwl2wywfgse35a3x", "addr1q86zwwlc25vhgc4pye50l2gqnqhs6takqdy5umla48nnldsellglm25utle5stjsgt7fpkkrnqr46xdcgshh4vzyzhlsxydwhp", "addr1vxlsvgpdqusfhceq0m4tunz4j7vyhd60qlyqglpjm7xu0xswl723x", "Ae2tdPwUPEZFRbyhz3cpfC2CumGzNkFBN2L42rcUc2yjQpEkxDbkPodpMAi", "279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a3f534e454b"])
    func aWellFormedAddressIsKept(_ address: String) throws {
        #expect(try CardanoChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["ADDR1QX2FXV2UMYHTTKXYXP8X0DLPDT3K6CWNG5PXJ3JHSYDZER3N0D3VLLMYQWSX5WKTCD8CC3SQ835LU7DRV2XWL2WYWFGSE35A3X", "stake1uyehkck0lajq8gr28t9uxnuvgcqrc6070x3k9r8048z8y5gh6ffgw", "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3n0d3vllmyqwsx5wktcd8cc3sq835lu7drv2xwl2wywfgse35b3x", "addr_test1vqlsvgpdqusfhceq0m4tunz4j7vyhd60qlyqglpjm7xu0xswl723x", "0x0", "Ae2tdPwUPEZFRbyhz0cpfC2Cum", "279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a", "279C909F348E533DA5808898F87F9A14BB2C3DFBBACCCD631D927A3F534E454B"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try CardanoChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try CardanoChain.default.contract(for: "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3n0d3vllmyqwsx5wktcd8cc3sq835lu7drv2xwl2wywfgse35a3x")
        let decoded: CardanoContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == CardanoChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(CardanoChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? CardanoContract)
        #expect(contract == CardanoChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: CardanoChain.default.id + ":" + "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3n0d3vllmyqwsx5wktcd8cc3sq835lu7drv2xwl2wywfgse35a3x")
        let contract = try #require(BlockChains.contract(of: account) as? CardanoContract)
        #expect(contract.address == "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3n0d3vllmyqwsx5wktcd8cc3sq835lu7drv2xwl2wywfgse35a3x")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "cardano", by: .coinGecko) == CardanoChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "cardano")?.chainId == CardanoChain.default.id)
    }

    /// CoinGecko's `milkomeda-cardano` platform is Milkomeda, an EVM chain (2001), not this chain, so it lands nowhere
    @Test func coinGeckosOtherPlatformIsNoAdmittedChain() {
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "milkomeda-cardano", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "milkomeda-cardano") == nil)
    }

    @Test func coinMarketCapsRowLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "Cardano", by: .coinMarketCap) == CardanoChain.default.id)
    }

    /// CoinMarketCap lists SNEK on Cardano at "0x0", an address the chain refuses, so it is left out of the list
    @Test func coinMarketCapsSnekAtZeroIsLeftOut() throws {
        let listing = """
        {
          "status": { "timestamp": "2026-10-07T00:00:00.000Z", "error_code": 0, "error_message": null,
                      "elapsed": 1, "credit_count": 1 },
          "data": [
            { "id": 25264, "name": "Snek", "symbol": "SNEK", "slug": "snek", "is_active": 1,
              "first_historical_data": "2023-05-01T00:00:00.000Z",
              "platform": { "id": 2010, "name": "Cardano", "symbol": "ADA", "slug": "cardano", "token_address": "0x0" } }
          ]
        }
        """
        let response = try JSONDecoder().decode(CurrencyMapResponse.self, from: Data(listing.utf8))
        #expect(try response.tokens(for: CardanoContract.self).isEmpty)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(CardanoChain.default.scanner.userReadableName == "Koios")
        #expect(Koios.endPoint.absoluteString == "https://api.koios.rest/api/v1")
    }

    /// The recorded `address_info` of CIP-19's first mainnet test vector: one UTxO of 1,000,000 lovelace, at ADA's
    /// declared 6
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: [Koios.AddressInfo] = try CoinGeckoRecorded.data("Cardano/address-info.json").fromJSON()
        let amount = try Koios.AddressInfo.amount(response)
        #expect(amount.quantity == 1_000_000)
        #expect(amount.currency == CardanoChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 6)
    }

    /// An address the ledger has never seen is answered with an empty list, which reads as zero
    @Test func anAddressNeverSeenReadsZero() throws {
        #expect(try Koios.AddressInfo.amount([]).quantity == 0)
    }

    /// The recorded `address_txs` lists one transaction, and the recorded `tx_info` of it: the vector received
    /// 1,000,000 lovelace from the first input's address, the fee 202,925 lovelace
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let listed: [Koios.AddressTransaction] = try CoinGeckoRecorded.data("Cardano/address-txs.json").fromJSON()
        #expect(listed.map(\.txHash) == ["2c80db2dc0e3a3b957d6e96c5d3b2ca024fccd9eed5319b0c65127896216baaf"])
        let account = try CardanoChain.default.contract(for: "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3n0d3vllmyqwsx5wktcd8cc3sq835lu7drv2xwl2wywfgse35a3x")
        let transactions = try CardanoChain.default.scanner.loadTransactions(
            from: CoinGeckoRecorded.data("Cardano/tx-info.json"), forAccount: account
        )
        try #require(transactions.count == 1)
        let read = Self.reading(transactions[0], as: CardanoContract.self)
        #expect(read.hash == "2c80db2dc0e3a3b957d6e96c5d3b2ca024fccd9eed5319b0c65127896216baaf")
        #expect(read.quantity == 1_000_000)
        #expect(read.fee == 202_925)
        #expect(read.from == "addr1q86zwwlc25vhgc4pye50l2gqnqhs6takqdy5umla48nnldsellglm25utle5stjsgt7fpkkrnqr46xdcgshh4vzyzhlsxydwhp")
        #expect(read.to == "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3n0d3vllmyqwsx5wktcd8cc3sq835lu7drv2xwl2wywfgse35a3x")
        #expect(read.currency == CardanoChain.default.mainContract && read.successful)
        #expect(read.timeStamp == Date(timeIntervalSince1970: 1_776_717_554))
    }

    /// The same answer read for the sender: it lost 1,352,925 lovelace, to the first output not its own
    @Test func theRecordedTransactionMapsForItsSender() throws {
        let sender = try CardanoChain.default.contract(
            for: "addr1q86zwwlc25vhgc4pye50l2gqnqhs6takqdy5umla48nnldsellglm25utle5stjsgt7fpkkrnqr46xdcgshh4vzyzhlsxydwhp"
        )
        let transactions = try CardanoChain.default.scanner.loadTransactions(
            from: CoinGeckoRecorded.data("Cardano/tx-info.json"), forAccount: sender
        )
        let first = try #require(transactions.first)
        let read = Self.reading(first, as: CardanoContract.self)
        #expect(read.quantity == 495_938_365 - 494_585_440)
        #expect(read.from == sender.address)
        #expect(read.to == "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3n0d3vllmyqwsx5wktcd8cc3sq835lu7drv2xwl2wywfgse35a3x")
    }

    /// A `tx_info` answer does not name the address it was asked about, so it is read only for an address
    @Test func transactionsAreNotReadWithoutTheirAddress() throws {
        #expect(throws: KoiosResponseError.self) { try CardanoChain.default.scanner.loadTransactions(from: Data("[]".utf8)) }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try CardanoChain.default.contract(for: "addr1qx2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3n0d3vllmyqwsx5wktcd8cc3sq835lu7drv2xwl2wywfgse35a3x")
        let snek = try CardanoChain.default.contract(for: "279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a3f534e454b")
        await #expect(throws: KoiosResponseError.self) {
            try await CardanoChain.default.scanner.getBalance(forToken: snek, forAccount: account)
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
