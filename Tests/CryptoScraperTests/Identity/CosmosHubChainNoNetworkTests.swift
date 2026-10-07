// CosmosHubChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Cosmos Hub:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct CosmosHubChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(CosmosHubChain.default.id == "cosmos:cosmoshub-4")
        #expect(CosmosHubChain.default.id == COSMOS.CosmosHub.chainId)
        let instance = try AssetInstance(validating: CosmosHubChain.default.id + ":" + "shape")
        #expect(instance.chainId == CosmosHubChain.default.id)
        #expect(CosmosHubChain.default.id.split(separator: ":").count == 2)
    }

    /// The cosmos form: the chain's own `chain_id` after `cosmos:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = CosmosHubChain.default.id.dropFirst("cosmos:".count)
        #expect(CosmosHubChain.default.id.hasPrefix("cosmos:"))
        #expect((1...32).contains(reference.count))
        #expect(reference.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(CosmosHubChain.default.mainContract.isChainToken)
        #expect(CosmosHubChain.default.mainContract.address == "atom")
        #expect(AssetInstance(CosmosHubChain.default.mainContract).id == COSMOS.CosmosHub.atom.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(CosmosHubChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 6)
        #expect(COSMOS.CosmosHub.atom.decimals == 6)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(COSMOS.CosmosHub.atom))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(CosmosHubChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == COSMOS.CosmosHub.atom)
        #expect(declaration.symbol.text == "ATOM")
        #expect(declaration.tokenName == "Cosmos")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(CosmosHubContract.Units.atom.divisorFromBase == Self.tenToThe(COSMOS.CosmosHub.atom.decimals))
        #expect(CosmosHubContract.Units.defaultDisplayUnits == .atom)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(CosmosHubContract.Units.uatom.divisorFromBase == Self.tenToThe(0))
        #expect(CosmosHubContract.Units.chainBaseUnits == .uatom)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9kn", "cosmos1jv65s3grqf6v6jl3dp4t6c9t9rk99cd88lyufl", "cosmos1qqqsyqcyq5rqwzqfpg9scrgwpugpzysnzs23v9ccrydpk8qarc0sxaggsw", "ibc/0025F8A87464A471E66B234C4F93AEC5B4DA3D42D7986451A059273426290DD5"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try CosmosHubChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["COSMOS10D07Y265GMMUVT4Z0W9AW880JNSR700J6ZN9KN", "cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9k", "cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9knq", "thor10d07y265gmmuvt4z0w9aw880jnsr700ju927rv", "cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9bn", "ibc/0025f8a87464a471e66b234c4f93aec5b4da3d42d7986451a059273426290dd5", "ibc/0025F8A87464A471E66B234C4F93AEC5B4DA3D42D7986451A059273426290DD", "cosmosvaloper10d07y265gmmuvt4z0w9aw880jnsr700j6zn9kn"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try CosmosHubChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try CosmosHubChain.default.contract(for: "cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9kn")
        let decoded: CosmosHubContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == CosmosHubChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(CosmosHubChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? CosmosHubContract)
        #expect(contract == CosmosHubChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: CosmosHubChain.default.id + ":" + "cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9kn")
        let contract = try #require(BlockChains.contract(of: account) as? CosmosHubContract)
        #expect(contract.address == "cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9kn")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "cosmos", by: .coinGecko) == CosmosHubChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "cosmos")?.chainId == CosmosHubChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(CosmosHubChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsTheChainsLCDReadWithNoUnwrap() {
        #expect(CosmosHubChain.default.scanner.userReadableName == "Cosmos LCD")
        #expect(CosmosHubChain.default.scanner.endPoint.absoluteString == "https://rest.cosmos.directory/cosmoshub")
        #expect(CosmosHubChain.default.scanner.denom == "uatom")
    }

    /// The recorded balances of the `gov` module's account, 501,124,548 uatom beside eight IBC denoms: the coin's at ATOM's declared 6
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: CosmosLCD<CosmosHubContract>.BalancesResponse = try CoinGeckoRecorded.data("CosmosHub/balances.json").fromJSON()
        let amount = try response.amount(of: CosmosHubChain.default.scanner.denom)
        #expect(amount.quantity == 501_124_548)
        #expect(amount.currency == CosmosHubChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 6)
    }

    /// The recorded transfers to the `gov` module's account: three proposals' deposits, each 500,000,000 uatom from
    /// its proposer, each fee its signer's in uatom
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let account = try CosmosHubChain.default.contract(for: "cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9kn")
        let transactions = try CosmosHubChain.default.scanner.loadTransactions(
            from: CoinGeckoRecorded.data("CosmosHub/txs.json"), forAccount: account
        )
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: CosmosHubContract.self) }
        #expect(reads.map(\.quantity) == [500_000_000, 500_000_000, 500_000_000])
        #expect(reads.map(\.fee) == [10909, 1911, 21545])
        #expect(reads.map(\.to) == ["cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9kn", "cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9kn", "cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9kn"])
        #expect(reads[0].from == "cosmos1705swa2kgn9pvancafzl254f63a3jda9ngdnc7")
        #expect(reads.allSatisfy { $0.currency == CosmosHubChain.default.mainContract && $0.successful })
        #expect(reads.allSatisfy { $0.type == "/cosmos.gov.v1.MsgSubmitProposal" })
        #expect(reads[0].hash == "84286805F057C572B70CA7BAA6EF10565F2C6658AE99435F2EF7B51B164F4597")
        let time = try Date("2026-10-05T11:58:17Z", strategy: .iso8601)
        #expect(reads[0].timeStamp == time)
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try CosmosHubChain.default.contract(for: "cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9kn")
        let token = try CosmosHubChain.default.contract(for: "ibc/0025F8A87464A471E66B234C4F93AEC5B4DA3D42D7986451A059273426290DD5")
        await #expect(throws: CosmosLCDResponseError.self) {
            try await CosmosHubChain.default.scanner.getBalance(forToken: token, forAccount: account)
        }
    }

    /// An LCD's answer does not name the address it was asked about, so it is read only for an address
    @Test func transactionsAreNotReadWithoutTheirAddress() throws {
        #expect(throws: CosmosLCDResponseError.self) { try CosmosHubChain.default.scanner.loadTransactions(from: Data("{}".utf8)) }
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
