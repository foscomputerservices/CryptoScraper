// VeChainChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for VeChain: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct VeChainChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(VeChainChain.default.id == "vechain:b1ac3413d346d43539627e6be7ec1b4a")
        #expect(VeChainChain.default.id == VECHAIN.VeChain.chainId)
        let instance = try AssetInstance(validating: VeChainChain.default.id + ":" + "shape")
        #expect(instance.chainId == VeChainChain.default.id)
        #expect(VeChainChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(VeChainChain.default.mainContract.isChainToken)
        #expect(VeChainChain.default.mainContract.address == "vet")
        #expect(AssetInstance(VeChainChain.default.mainContract).id == VECHAIN.VeChain.vet.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(VeChainChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 18)
        #expect(VECHAIN.VeChain.vet.decimals == 18)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(VECHAIN.VeChain.vet))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(VeChainChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == VECHAIN.VeChain.vet)
        #expect(declaration.symbol.text == "VET")
        #expect(declaration.tokenName == "VeChain")
    }

    /// VTHO, the chain's second native coin, under its own placeholder and its own declaration (design § 2.5)
    @Test func vthoIsItsOwnDeclaredInstanceOnTheChain() throws {
        let vtho = try VeChainChain.default.contract(for: "vtho")
        #expect(!vtho.isChainToken)
        #expect(AssetInstance(vtho).id == VECHAIN.VeChain.vtho.instance.id)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(vtho)) == 18)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: AssetInstance(vtho)))
        #expect(declaration.instances.first == VECHAIN.VeChain.vtho)
        #expect(declaration.symbol.text == "VTHO")
        #expect(try !AssetRegistry.shared.isEquivalent(AssetInstance(vtho), AssetInstance(VeChainChain.default.mainContract)))
        let back = try #require(BlockChains.contract(of: VECHAIN.VeChain.vtho.instance) as? VeChainContract)
        #expect(back == vtho)
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(VeChainContract.Units.vet.divisorFromBase == Self.tenToThe(VECHAIN.VeChain.vet.decimals))
        #expect(VeChainContract.Units.defaultDisplayUnits == .vet)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(VeChainContract.Units.wei.divisorFromBase == Self.tenToThe(0))
        #expect(VeChainContract.Units.chainBaseUnits == .wei)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try VeChainChain.default.contract(for: "0x0000000000000000000000000000456e65726779").address == "0x0000000000000000000000000000456e65726779")
    }

    @Test(arguments: ["0x0", "5034aa590125b64023a0262112b98d72e3c8e40e", "0x5034aa590125b64023a0262112b98d72e3c8e4zz"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try VeChainChain.default.contract(for: address) }
    }

    /// An address is lower-cased, as the EVM chains' addresses are
    @Test func anAddressIsNormalizedByTheChain() throws {
        #expect(try VeChainChain.default.contract(for: "0x5034AA590125b64023a0262112b98d72e3c8e40e").address == "0x5034aa590125b64023a0262112b98d72e3c8e40e")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try VeChainChain.default.contract(for: "0x0000000000000000000000000000456e65726779")
        let decoded: VeChainContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == VeChainChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(VeChainChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? VeChainContract)
        #expect(contract == VeChainChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: VeChainChain.default.id + ":" + "0x0000000000000000000000000000456e65726779")
        let contract = try #require(BlockChains.contract(of: account) as? VeChainContract)
        #expect(contract.address == "0x0000000000000000000000000000456e65726779")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "vechain", by: .coinGecko) == VeChainChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "vechain")?.chainId == VeChainChain.default.id)
    }

    @Test func coinMarketCapsRowLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "VeChain", by: .coinMarketCap) == VeChainChain.default.id)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(VeChainChain.default.scanner.userReadableName == "VeChainThor")
    }

    /// The recorded Energy contract's account: no VET, and 6,090,888.297820508239410847 VTHO in wei, each at its
    /// declared 18
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: VeChainThor.AccountResponse = try CoinGeckoRecorded.data("VeChain/account.json").fromJSON()
        let vet = try response.amount(of: VeChainChain.default.mainContract)
        #expect(vet.quantity == 0)
        #expect(vet.currency == VeChainChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(vet.currency)) == 18)
    }

    /// VTHO is read from the same answer, as the node's `energy`
    @Test func theRecordedEnergyIsVTHOAtItsDecimals() throws {
        let response: VeChainThor.AccountResponse = try CoinGeckoRecorded.data("VeChain/account.json").fromJSON()
        let vtho = try VeChainChain.default.contract(for: "vtho")
        let amount = try response.amount(of: vtho)
        #expect(amount.quantity == 6_090_888_297_820_508_239_410_847)
        #expect(amount.currency == vtho)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 18)
    }

    /// The recorded transfer log to the Energy contract is empty
    @Test func theRecordedTransfersAreEmpty() throws {
        #expect(try VeChainChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("VeChain/logs-transfer.json")).isEmpty)
    }

    /// NOT A RECORDING: `/logs/transfer` in the shape VeChainThor's API gives, its values made up (the recorded answer
    /// is empty), one VET transfer of 2 VET, to show the mapping
    @Test func aTransferInTheDocumentedShapeMapsToVET() throws {
        let documented = """
        [{"sender":"0x5034aa590125b64023a0262112b98d72e3c8e40e","recipient":"0x0000000000000000000000000000456e65726779","amount":"0x1bc16d674ec80000","meta":{"blockID":"0x00","blockNumber":1,"blockTimestamp":1791000000,"txID":"0xmadeup","txOrigin":"0x5034aa590125b64023a0262112b98d72e3c8e40e","clauseIndex":0}}]
        """
        let transactions = try VeChainChain.default.scanner.loadTransactions(from: Data(documented.utf8))
        try #require(transactions.count == 1)
        let read = Self.reading(transactions[0], as: VeChainContract.self)
        #expect(read.currency == VeChainChain.default.mainContract)
        #expect(read.quantity == 2_000_000_000_000_000_000)
        #expect(read.from == "0x5034aa590125b64023a0262112b98d72e3c8e40e")
        #expect(read.to == "0x0000000000000000000000000000456e65726779")
        #expect(read.timeStamp == Date(timeIntervalSince1970: 1_791_000_000))
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try VeChainChain.default.contract(for: "0x0000000000000000000000000000456e65726779")
        await #expect(throws: VeChainThorResponseError.self) {
            try await VeChainChain.default.scanner.getBalance(forToken: account, forAccount: account)
        }
    }

    /// CoinMarketCap lists VTHO on VeChain at "0x0", an address the chain refuses, so it is left out of the list
    @Test func coinMarketCapsVTHOAtZeroIsLeftOut() throws {
        let listing = """
        {
          "status": { "timestamp": "2026-10-07T00:00:00.000Z", "error_code": 0, "error_message": null,
                      "elapsed": 1, "credit_count": 1 },
          "data": [
            { "id": 3012, "name": "VeThor Token", "symbol": "VTHO", "slug": "vethor-token", "is_active": 1,
              "first_historical_data": "2018-08-01T00:00:00.000Z",
              "platform": { "id": 3077, "name": "VeChain", "symbol": "VET", "slug": "vechain", "token_address": "0x0" } }
          ]
        }
        """
        let response = try JSONDecoder().decode(CurrencyMapResponse.self, from: Data(listing.utf8))
        #expect(try response.tokens(for: VeChainContract.self).isEmpty)
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
