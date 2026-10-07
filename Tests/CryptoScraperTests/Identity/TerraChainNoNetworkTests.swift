// TerraChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Terra:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct TerraChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(TerraChain.default.id == "cosmos:phoenix-1")
        #expect(TerraChain.default.id == COSMOS.Terra.chainId)
        let instance = try AssetInstance(validating: TerraChain.default.id + ":" + "shape")
        #expect(instance.chainId == TerraChain.default.id)
        #expect(TerraChain.default.id.split(separator: ":").count == 2)
    }

    /// The cosmos form: the chain's own `chain_id` after `cosmos:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = TerraChain.default.id.dropFirst("cosmos:".count)
        #expect(TerraChain.default.id.hasPrefix("cosmos:"))
        #expect((1...32).contains(reference.count))
        #expect(reference.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(TerraChain.default.mainContract.isChainToken)
        #expect(TerraChain.default.mainContract.address == "luna")
        #expect(AssetInstance(TerraChain.default.mainContract).id == COSMOS.Terra.luna.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(TerraChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 6)
        #expect(COSMOS.Terra.luna.decimals == 6)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(COSMOS.Terra.luna))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(TerraChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == COSMOS.Terra.luna)
        #expect(declaration.symbol.text == "LUNA")
        #expect(declaration.tokenName == "Terra")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(TerraContract.Units.luna.divisorFromBase == Self.tenToThe(COSMOS.Terra.luna.decimals))
        #expect(TerraContract.Units.defaultDisplayUnits == .luna)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(TerraContract.Units.uluna.divisorFromBase == Self.tenToThe(0))
        #expect(TerraContract.Units.chainBaseUnits == .uluna)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["terra10d07y265gmmuvt4z0w9aw880jnsr700juxf95n", "terra1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8pm7utl", "terra1qqqsyqcyq5rqwzqfpg9scrgwpugpzysnzs23v9ccrydpk8qarc0srftjj3", "ibc/0025F8A87464A471E66B234C4F93AEC5B4DA3D42D7986451A059273426290DD5"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try TerraChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["TERRA10D07Y265GMMUVT4Z0W9AW880JNSR700JUXF95N", "terra10d07y265gmmuvt4z0w9aw880jnsr700juxf95", "terra10d07y265gmmuvt4z0w9aw880jnsr700juxf95nq", "thor10d07y265gmmuvt4z0w9aw880jnsr700ju927rv", "terra10d07y265gmmuvt4z0w9aw880jnsr700juxf9bn", "ibc/0025f8a87464a471e66b234c4f93aec5b4da3d42d7986451a059273426290dd5", "ibc/0025F8A87464A471E66B234C4F93AEC5B4DA3D42D7986451A059273426290DD", "terravaloper10d07y265gmmuvt4z0w9aw880jnsr700juxf95n"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try TerraChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try TerraChain.default.contract(for: "terra1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8pm7utl")
        let decoded: TerraContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == TerraChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(TerraChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? TerraContract)
        #expect(contract == TerraChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: TerraChain.default.id + ":" + "terra1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8pm7utl")
        let contract = try #require(BlockChains.contract(of: account) as? TerraContract)
        #expect(contract.address == "terra1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8pm7utl")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "terra-2", by: .coinGecko) == TerraChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "terra-2")?.chainId == TerraChain.default.id)
    }

    /// CoinGecko's `terra` platform is Terra Classic (`columbus-5`), not this chain, so it lands nowhere
    @Test func coinGeckosClassicPlatformIsNoAdmittedChain() {
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "terra", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "terra") == nil)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(TerraChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsTheChainsLCDReadWithNoUnwrap() {
        #expect(TerraChain.default.scanner.userReadableName == "Cosmos LCD")
        #expect(TerraChain.default.scanner.endPoint.absoluteString == "https://rest.cosmos.directory/terra2")
        #expect(TerraChain.default.scanner.denom == "uluna")
    }

    /// The recorded balances of the `distribution` module's account, 263,404,969,321,668 uluna beside four other denoms: the coin's at LUNA's declared 6
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: CosmosLCD<TerraContract>.BalancesResponse = try CoinGeckoRecorded.data("Terra/balances-distribution.json").fromJSON()
        let amount = try response.amount(of: TerraChain.default.scanner.denom)
        #expect(amount.quantity == 263_404_969_321_668)
        #expect(amount.currency == TerraChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 6)
    }

    /// The recorded balances of the `gov` module's account: none, which reads as zero
    @Test func anAddressHoldingNoneReadsZero() throws {
        let response: CosmosLCD<TerraContract>.BalancesResponse = try CoinGeckoRecorded.data("Terra/balances.json").fromJSON()
        #expect(try response.amount(of: TerraChain.default.scanner.denom).quantity == 0)
    }

    /// The recorded transfers to the `distribution` module's account: three of 10,000,000 uluna from a CosmWasm
    /// contract (a 32-byte address), each fee its signer's in uluna
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let account = try TerraChain.default.contract(for: "terra1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8pm7utl")
        let transactions = try TerraChain.default.scanner.loadTransactions(
            from: CoinGeckoRecorded.data("Terra/txs.json"), forAccount: account
        )
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: TerraContract.self) }
        #expect(reads.map(\.quantity) == [10_000_000, 10_000_000, 10_000_000])
        #expect(reads.map(\.fee) == [30900, 30750, 30987])
        #expect(reads.allSatisfy { $0.from == "terra1zly98gvcec54m3caxlqexce7rus6rzgplz7eketsdz7nh750h2rqvu8uzx" })
        #expect(reads.allSatisfy { $0.to == "terra1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8pm7utl" && $0.successful })
        #expect(reads.allSatisfy { $0.type == "/cosmwasm.wasm.v1.MsgExecuteContract" })
        #expect(reads[0].hash == "67F8F44418DEC6DDCBF1BD3E60EAE3C89DFBDB29C185EB13FFFD2D62F1672738")
        let time = try Date("2026-09-28T00:10:49Z", strategy: .iso8601)
        #expect(reads[0].timeStamp == time)
        #expect(try TerraChain.default.contract(for: reads[0].from!).address == reads[0].from)
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try TerraChain.default.contract(for: "terra1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8pm7utl")
        let token = try TerraChain.default.contract(for: "ibc/0025F8A87464A471E66B234C4F93AEC5B4DA3D42D7986451A059273426290DD5")
        await #expect(throws: CosmosLCDResponseError.self) {
            try await TerraChain.default.scanner.getBalance(forToken: token, forAccount: account)
        }
    }

    /// An LCD's answer does not name the address it was asked about, so it is read only for an address
    @Test func transactionsAreNotReadWithoutTheirAddress() throws {
        #expect(throws: CosmosLCDResponseError.self) { try TerraChain.default.scanner.loadTransactions(from: Data("{}".utf8)) }
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
