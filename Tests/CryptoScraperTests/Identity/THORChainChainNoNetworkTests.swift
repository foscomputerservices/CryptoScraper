// THORChainChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for THORChain:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct THORChainChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(THORChainChain.default.id == "cosmos:thorchain-1")
        #expect(THORChainChain.default.id == COSMOS.THORChain.chainId)
        let instance = try AssetInstance(validating: THORChainChain.default.id + ":" + "shape")
        #expect(instance.chainId == THORChainChain.default.id)
        #expect(THORChainChain.default.id.split(separator: ":").count == 2)
    }

    /// The cosmos form: the chain's own `chain_id` after `cosmos:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = THORChainChain.default.id.dropFirst("cosmos:".count)
        #expect(THORChainChain.default.id.hasPrefix("cosmos:"))
        #expect((1...32).contains(reference.count))
        #expect(reference.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(THORChainChain.default.mainContract.isChainToken)
        #expect(THORChainChain.default.mainContract.address == "rune")
        #expect(AssetInstance(THORChainChain.default.mainContract).id == COSMOS.THORChain.rune.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(THORChainChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(COSMOS.THORChain.rune.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(COSMOS.THORChain.rune))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(THORChainChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == COSMOS.THORChain.rune)
        #expect(declaration.symbol.text == "RUNE")
        #expect(declaration.tokenName == "THORChain")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(THORChainContract.Units.rune.divisorFromBase == Self.tenToThe(COSMOS.THORChain.rune.decimals))
        #expect(THORChainContract.Units.defaultDisplayUnits == .rune)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(THORChainContract.Units.base.divisorFromBase == Self.tenToThe(0))
        #expect(THORChainContract.Units.chainBaseUnits == .base)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["thor10d07y265gmmuvt4z0w9aw880jnsr700ju927rv", "thor1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8pca8uq", "thor1qqqsyqcyq5rqwzqfpg9scrgwpugpzysnzs23v9ccrydpk8qarc0sztexdf", "ibc/0025F8A87464A471E66B234C4F93AEC5B4DA3D42D7986451A059273426290DD5"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try THORChainChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["THOR10D07Y265GMMUVT4Z0W9AW880JNSR700JU927RV", "thor10d07y265gmmuvt4z0w9aw880jnsr700ju927r", "thor10d07y265gmmuvt4z0w9aw880jnsr700ju927rvq", "cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9kn", "thor10d07y265gmmuvt4z0w9aw880jnsr700ju927bv", "ibc/0025f8a87464a471e66b234c4f93aec5b4da3d42d7986451a059273426290dd5", "ibc/0025F8A87464A471E66B234C4F93AEC5B4DA3D42D7986451A059273426290DD", "thorvaloper10d07y265gmmuvt4z0w9aw880jnsr700ju927rv"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try THORChainChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try THORChainChain.default.contract(for: "thor1dheycdevq39qlkxs2a6wuuzyn4aqxhve4qxtxt")
        let decoded: THORChainContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == THORChainChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(THORChainChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? THORChainContract)
        #expect(contract == THORChainChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: THORChainChain.default.id + ":" + "thor1dheycdevq39qlkxs2a6wuuzyn4aqxhve4qxtxt")
        let contract = try #require(BlockChains.contract(of: account) as? THORChainContract)
        #expect(contract.address == "thor1dheycdevq39qlkxs2a6wuuzyn4aqxhve4qxtxt")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "thorchain", by: .coinGecko) == THORChainChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "thorchain")?.chainId == THORChainChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(THORChainChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsTheChainsLCDReadWithNoUnwrap() {
        #expect(THORChainChain.default.scanner.userReadableName == "Cosmos LCD")
        #expect(THORChainChain.default.scanner.endPoint.absoluteString == "https://rest.cosmos.directory/thorchain")
        #expect(THORChainChain.default.scanner.denom == "rune")
    }

    /// The recorded balances of the `reserve` module's account, 2,532,193,121,980,653 rune beside thirteen other denoms: the coin's at RUNE's declared 8
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: CosmosLCD<THORChainContract>.BalancesResponse = try CoinGeckoRecorded.data("THORChain/balances.json").fromJSON()
        let amount = try response.amount(of: THORChainChain.default.scanner.denom)
        #expect(amount.quantity == 2_532_193_121_980_653)
        #expect(amount.currency == THORChainChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 8)
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try THORChainChain.default.contract(for: "thor1dheycdevq39qlkxs2a6wuuzyn4aqxhve4qxtxt")
        let token = try THORChainChain.default.contract(for: "ibc/0025F8A87464A471E66B234C4F93AEC5B4DA3D42D7986451A059273426290DD5")
        await #expect(throws: CosmosLCDResponseError.self) {
            try await THORChainChain.default.scanner.getBalance(forToken: token, forAccount: account)
        }
    }

    /// An LCD's answer does not name the address it was asked about, so it is read only for an address
    @Test func transactionsAreNotReadWithoutTheirAddress() throws {
        #expect(throws: CosmosLCDResponseError.self) { try THORChainChain.default.scanner.loadTransactions(from: Data("{}".utf8)) }
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
