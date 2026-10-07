// FetchAIChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Fetch.ai:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct FetchAIChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(FetchAIChain.default.id == "cosmos:fetchhub-4")
        #expect(FetchAIChain.default.id == COSMOS.FetchAI.chainId)
        let instance = try AssetInstance(validating: FetchAIChain.default.id + ":" + "shape")
        #expect(instance.chainId == FetchAIChain.default.id)
        #expect(FetchAIChain.default.id.split(separator: ":").count == 2)
    }

    /// The cosmos form: the chain's own `chain_id` after `cosmos:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = FetchAIChain.default.id.dropFirst("cosmos:".count)
        #expect(FetchAIChain.default.id.hasPrefix("cosmos:"))
        #expect((1...32).contains(reference.count))
        #expect(reference.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(FetchAIChain.default.mainContract.isChainToken)
        #expect(FetchAIChain.default.mainContract.address == "fet")
        #expect(AssetInstance(FetchAIChain.default.mainContract).id == COSMOS.FetchAI.fet.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(FetchAIChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 18)
        #expect(COSMOS.FetchAI.fet.decimals == 18)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(COSMOS.FetchAI.fet))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(FetchAIChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == COSMOS.FetchAI.fet)
        #expect(declaration.symbol.text == "FET")
        #expect(declaration.tokenName == "Artificial Superintelligence Alliance")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(FetchAIContract.Units.fet.divisorFromBase == Self.tenToThe(COSMOS.FetchAI.fet.decimals))
        #expect(FetchAIContract.Units.defaultDisplayUnits == .fet)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(FetchAIContract.Units.afet.divisorFromBase == Self.tenToThe(0))
        #expect(FetchAIContract.Units.chainBaseUnits == .afet)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["fetch10d07y265gmmuvt4z0w9aw880jnsr700jfl6p5y", "fetch1jv65s3grqf6v6jl3dp4t6c9t9rk99cd85zdctg", "fetch1qqqsyqcyq5rqwzqfpg9scrgwpugpzysnzs23v9ccrydpk8qarc0s3495es", "ibc/0025F8A87464A471E66B234C4F93AEC5B4DA3D42D7986451A059273426290DD5"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try FetchAIChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["FETCH10D07Y265GMMUVT4Z0W9AW880JNSR700JFL6P5Y", "fetch10d07y265gmmuvt4z0w9aw880jnsr700jfl6p5", "fetch10d07y265gmmuvt4z0w9aw880jnsr700jfl6p5yq", "thor10d07y265gmmuvt4z0w9aw880jnsr700ju927rv", "fetch10d07y265gmmuvt4z0w9aw880jnsr700jfl6pby", "ibc/0025f8a87464a471e66b234c4f93aec5b4da3d42d7986451a059273426290dd5", "ibc/0025F8A87464A471E66B234C4F93AEC5B4DA3D42D7986451A059273426290DD", "fetchvaloper10d07y265gmmuvt4z0w9aw880jnsr700jfl6p5y"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try FetchAIChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try FetchAIChain.default.contract(for: "fetch1jv65s3grqf6v6jl3dp4t6c9t9rk99cd85zdctg")
        let decoded: FetchAIContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == FetchAIChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(FetchAIChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? FetchAIContract)
        #expect(contract == FetchAIChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: FetchAIChain.default.id + ":" + "fetch1jv65s3grqf6v6jl3dp4t6c9t9rk99cd85zdctg")
        let contract = try #require(BlockChains.contract(of: account) as? FetchAIContract)
        #expect(contract.address == "fetch1jv65s3grqf6v6jl3dp4t6c9t9rk99cd85zdctg")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko names no Fetch.ai platform (its `fetch-ai` coin is a token on Ethereum), so the table has no row for the chain
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(FetchAIChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(FetchAIChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsTheChainsLCDReadWithNoUnwrap() {
        #expect(FetchAIChain.default.scanner.userReadableName == "Cosmos LCD")
        #expect(FetchAIChain.default.scanner.endPoint.absoluteString == "https://rest-fetchhub.fetch.ai")
        #expect(FetchAIChain.default.scanner.denom == "afet")
    }

    /// The recorded balances of the `distribution` module's account, 7,448,407,184,562,817,856,309,069 afet, past an Int64, beside `nanomobx`: the coin's at FET's declared 18
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: CosmosLCD<FetchAIContract>.BalancesResponse = try CoinGeckoRecorded.data("FetchAI/balances-distribution.json").fromJSON()
        let amount = try response.amount(of: FetchAIChain.default.scanner.denom)
        #expect(amount.quantity == 7_448_407_184_562_817_856_309_069)
        #expect(amount.currency == FetchAIChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 18)
    }

    /// The recorded balances of the `gov` module's account: none, which reads as zero
    @Test func anAddressHoldingNoneReadsZero() throws {
        let response: CosmosLCD<FetchAIContract>.BalancesResponse = try CoinGeckoRecorded.data("FetchAI/balances.json").fromJSON()
        #expect(try response.amount(of: FetchAIChain.default.scanner.denom).quantity == 0)
    }

    /// The recorded transfers to the `distribution` module's account: none listed
    @Test func theRecordedEmptyAnswerHoldsNoTransactions() throws {
        let account = try FetchAIChain.default.contract(for: "fetch1jv65s3grqf6v6jl3dp4t6c9t9rk99cd85zdctg")
        let transactions = try FetchAIChain.default.scanner.loadTransactions(
            from: CoinGeckoRecorded.data("FetchAI/txs.json"), forAccount: account
        )
        #expect(transactions.isEmpty)
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try FetchAIChain.default.contract(for: "fetch1jv65s3grqf6v6jl3dp4t6c9t9rk99cd85zdctg")
        let token = try FetchAIChain.default.contract(for: "ibc/0025F8A87464A471E66B234C4F93AEC5B4DA3D42D7986451A059273426290DD5")
        await #expect(throws: CosmosLCDResponseError.self) {
            try await FetchAIChain.default.scanner.getBalance(forToken: token, forAccount: account)
        }
    }

    /// An LCD's answer does not name the address it was asked about, so it is read only for an address
    @Test func transactionsAreNotReadWithoutTheirAddress() throws {
        #expect(throws: CosmosLCDResponseError.self) { try FetchAIChain.default.scanner.loadTransactions(from: Data("{}".utf8)) }
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
