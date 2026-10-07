// FlowChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Flow: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct FlowChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(FlowChain.default.id == "flow:mainnet")
        #expect(FlowChain.default.id == FLOW.Flow.chainId)
        let instance = try AssetInstance(validating: FlowChain.default.id + ":" + "shape")
        #expect(instance.chainId == FlowChain.default.id)
        #expect(FlowChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(FlowChain.default.mainContract.isChainToken)
        #expect(FlowChain.default.mainContract.address == "flow")
        #expect(AssetInstance(FlowChain.default.mainContract).id == FLOW.Flow.flow.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(FlowChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(FLOW.Flow.flow.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(FLOW.Flow.flow))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(FlowChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == FLOW.Flow.flow)
        #expect(declaration.symbol.text == "FLOW")
        #expect(declaration.tokenName == "Flow")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(FlowContract.Units.flow.divisorFromBase == Self.tenToThe(FLOW.Flow.flow.decimals))
        #expect(FlowContract.Units.defaultDisplayUnits == .flow)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(FlowContract.Units.base.divisorFromBase == Self.tenToThe(0))
        #expect(FlowContract.Units.chainBaseUnits == .base)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try FlowChain.default.contract(for: "0x1654653399040a61").address == "0x1654653399040a61")
    }

    @Test(arguments: ["1654653399040a61", "0x1654653399040a6", "0x1654653399040a6z", "A.b19436aae4d94622", "B.b19436aae4d94622.FiatToken"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try FlowChain.default.contract(for: address) }
    }

    /// An account is a number, so its hex is lower-cased
    @Test func anAddressIsNormalizedByTheChain() throws {
        #expect(try FlowChain.default.contract(for: "0x1654653399040A61").address == "0x1654653399040a61")
    }

    /// A contract as Cadence names it is kept as given
    @Test func aCadenceContractIsKeptAsGiven() throws {
        #expect(try FlowChain.default.contract(for: "A.b19436aae4d94622.FiatToken").address == "A.b19436aae4d94622.FiatToken")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try FlowChain.default.contract(for: "0x1654653399040a61")
        let decoded: FlowContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == FlowChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(FlowChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? FlowContract)
        #expect(contract == FlowChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: FlowChain.default.id + ":" + "0x1654653399040a61")
        let contract = try #require(BlockChains.contract(of: account) as? FlowContract)
        #expect(contract.address == "0x1654653399040a61")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "flow", by: .coinGecko) == FlowChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "flow")?.chainId == FlowChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(FlowChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(FlowChain.default.scanner.userReadableName == "Flow Access API")
    }

    /// The recorded FlowToken contract's account: 249.64085160 FLOW in its base count, at FLOW's declared 8
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: FlowAccessAPI.AccountResponse = try CoinGeckoRecorded.data("Flow/account.json").fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 24_964_085_160)
        #expect(amount.currency == FlowChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 8)
    }

    /// The Access API lists no account's transactions, so the scanner says so rather than answer none
    @Test func theTransactionsAreNotReadAndSaySo() async throws {
        let account = try FlowChain.default.contract(for: "0x1654653399040a61")
        await #expect(throws: FlowAccessAPIResponseError.self) {
            try await FlowChain.default.scanner.getTransactions(forAccount: account)
        }
        #expect(throws: FlowAccessAPIResponseError.self) { try FlowChain.default.scanner.loadTransactions(from: Data("{}".utf8)) }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try FlowChain.default.contract(for: "0x1654653399040a61")
        let token = try FlowChain.default.contract(for: "A.b19436aae4d94622.FiatToken")
        await #expect(throws: FlowAccessAPIResponseError.self) {
            try await FlowChain.default.scanner.getBalance(forToken: token, forAccount: account)
        }
    }


    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
