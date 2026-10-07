// AlgorandChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Algorand: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct AlgorandChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(AlgorandChain.default.id == "algorand:wGHE2Pwdvd7S12BL5FaOP20EGYesN73k")
        #expect(AlgorandChain.default.id == ALGORAND.Algorand.chainId)
        let instance = try AssetInstance(validating: AlgorandChain.default.id + ":" + "shape")
        #expect(instance.chainId == AlgorandChain.default.id)
        #expect(AlgorandChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(AlgorandChain.default.mainContract.isChainToken)
        #expect(AlgorandChain.default.mainContract.address == "algo")
        #expect(AssetInstance(AlgorandChain.default.mainContract).id == ALGORAND.Algorand.algo.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(AlgorandChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 6)
        #expect(ALGORAND.Algorand.algo.decimals == 6)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(ALGORAND.Algorand.algo))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(AlgorandChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == ALGORAND.Algorand.algo)
        #expect(declaration.symbol.text == "ALGO")
        #expect(declaration.tokenName == "Algorand")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(AlgorandContract.Units.algo.divisorFromBase == Self.tenToThe(ALGORAND.Algorand.algo.decimals))
        #expect(AlgorandContract.Units.defaultDisplayUnits == .algo)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(AlgorandContract.Units.microalgo.divisorFromBase == Self.tenToThe(0))
        #expect(AlgorandContract.Units.chainBaseUnits == .microalgo)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try AlgorandChain.default.contract(for: "2UEQTE5QDNXPI7M3TU44G6SYKLFWLPQO7EBZM7K7MHMQQMFI4QJPLHQFHM").address == "2UEQTE5QDNXPI7M3TU44G6SYKLFWLPQO7EBZM7K7MHMQQMFI4QJPLHQFHM")
    }

    @Test(arguments: ["2ueqte5qdnxpi7m3tu44g6syklfwlpqo7ebzm7k7mhmqqmfi4qjplhqfhm", "2UEQTE5QDNXPI7M3TU44G6SYKLFWLPQO7EBZM7K7MHMQQMFI4QJPLHQFH", "31566704x"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try AlgorandChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try AlgorandChain.default.contract(for: "2UEQTE5QDNXPI7M3TU44G6SYKLFWLPQO7EBZM7K7MHMQQMFI4QJPLHQFHM")
        let decoded: AlgorandContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == AlgorandChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(AlgorandChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? AlgorandContract)
        #expect(contract == AlgorandChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: AlgorandChain.default.id + ":" + "2UEQTE5QDNXPI7M3TU44G6SYKLFWLPQO7EBZM7K7MHMQQMFI4QJPLHQFHM")
        let contract = try #require(BlockChains.contract(of: account) as? AlgorandContract)
        #expect(contract.address == "2UEQTE5QDNXPI7M3TU44G6SYKLFWLPQO7EBZM7K7MHMQQMFI4QJPLHQFHM")
    }

    /// A generated token on the chain, from CoinGecko's recorded detail: its contract through the bridge, its
    /// decimals in the shared statement, the chain's 6 (design § 4.1)
    @Test func theGeneratedUsdCoinIsItsContractAtItsDecimals() throws {
        let token = ALGORAND.Algorand.usdCoin
        let contract = try #require(BlockChains.contract(of: token.instance) as? AlgorandContract)
        #expect(contract.address == "31566704")
        #expect(try AssetRegistry.shared.asset(of: token.instance) == .usdc)
        #expect(try AssetRegistry.shared.decimals(of: token.instance) == 6)
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "algorand", by: .coinGecko) == AlgorandChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "algorand")?.chainId == AlgorandChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(AlgorandChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(AlgorandChain.default.scanner.userReadableName == "AlgoNode")
    }

    /// The recorded account (USDC's reserve): 5,401,727,855 microalgos at ALGO's declared 6
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: AlgoNode.AccountResponse = try CoinGeckoRecorded.data("Algorand/account.json").fromJSON()
        let amount = response.amount()
        #expect(amount.quantity == 5_401_727_855)
        #expect(amount.currency == AlgorandChain.default.mainContract)
        #expect(amount.value() == 5_401.727855)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 6)
    }

    /// The recorded transactions: three USDC transfers, each in USDC's contract (its asset id), the fee in microalgos
    @Test func theRecordedTransactionsMapToTheirAsset() throws {
        let transactions = try AlgorandChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("Algorand/transactions.json"))
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: AlgorandContract.self) }
        #expect(reads.map(\.quantity) == [341_490_000, 0, 291_000_000])
        #expect(reads.allSatisfy { $0.currency?.address == "31566704" && $0.fee == 1_000 && $0.successful })
        #expect(reads[0].from == "TGYXKLVNWWWOY66DF7EB4WMGG76SRBJVKK6P5PLX7MQO2YAYTPIPN35OL4")
        #expect(reads[0].to == "2UEQTE5QDNXPI7M3TU44G6SYKLFWLPQO7EBZM7K7MHMQQMFI4QJPLHQFHM")
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: 1_791_369_904))
        #expect(reads.allSatisfy { $0.type == "axfer" })
    }

    /// The chain is the oracle of an asset's decimals: its recorded statement of USDC (ASA 31566704) says 6
    @Test func theChainStatesUSDCsDecimals() throws {
        let response: AlgoNode.AssetResponse = try CoinGeckoRecorded.data("Algorand/asset-31566704.json").fromJSON()
        let usdc = try AlgorandChain.default.contract(for: "31566704")
        let info = response.tokenInfo(for: usdc)
        #expect(info.decimals == 6)
        #expect(info.symbol == "USDC")
        #expect(info.contractAddress == usdc)
    }

    /// Design § 4.1, a token's decimals come from its chain's scanner: CoinGecko's recorded detail states USDC on
    /// Algorand at 5 decimals, the chain at 6, and the generated statement carries the chain's 6, the disagreement
    /// reported. When either source changes, this fails.
    @Test func theChainsUSDCDecimalsOnAlgorandWinOverCoinGeckos() throws {
        let response: AlgoNode.AssetResponse = try CoinGeckoRecorded.data("Algorand/asset-31566704.json").fromJSON()
        let chainsDecimals = response.tokenInfo(for: try AlgorandChain.default.contract(for: "31566704")).decimals
        let coinGeckosDecimals = try CoinGeckoRecorded.coin("usd-coin").detailPlatforms["algorand"]?.decimalPlace
        let statementsDecimals = try AssetRegistry.shared.decimals(of: ALGORAND.Algorand.usdCoin.instance)
        #expect(chainsDecimals == 6)
        #expect(coinGeckosDecimals == 5)
        #expect(statementsDecimals == 6)
        let (_, report) = try AssetImporter.generate(
            coins: [CoinGeckoRecorded.coin("usd-coin")], date: CoinGeckoRecorded.date,
            chainDecimals: CoinGeckoRecorded.chainDecimals()
        )
        #expect(report.findings.contains(.decimalsDisagree(coinId: "usd-coin", platform: "algorand", kept: 6, refused: 5)))
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let usdc = try AlgorandChain.default.contract(for: "31566704")
        let account = try AlgorandChain.default.contract(for: "2UEQTE5QDNXPI7M3TU44G6SYKLFWLPQO7EBZM7K7MHMQQMFI4QJPLHQFHM")
        await #expect(throws: AlgoNodeResponseError.self) {
            try await AlgorandChain.default.scanner.getBalance(forToken: usdc, forAccount: account)
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
