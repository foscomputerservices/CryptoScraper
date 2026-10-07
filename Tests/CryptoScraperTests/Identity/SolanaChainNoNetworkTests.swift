// SolanaChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Solana: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct SolanaChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(SolanaChain.default.id == "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")
        #expect(SolanaChain.default.id == SOLANA.Solana.chainId)
        let instance = try AssetInstance(validating: SolanaChain.default.id + ":" + "shape")
        #expect(instance.chainId == SolanaChain.default.id)
        #expect(SolanaChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(SolanaChain.default.mainContract.isChainToken)
        #expect(SolanaChain.default.mainContract.address == "sol")
        #expect(AssetInstance(SolanaChain.default.mainContract).id == SOLANA.Solana.sol.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(SolanaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 9)
        #expect(SOLANA.Solana.sol.decimals == 9)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(SOLANA.Solana.sol))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(SolanaChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == SOLANA.Solana.sol)
        #expect(declaration.symbol.text == "SOL")
        #expect(declaration.tokenName == "Solana")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(SolanaContract.Units.sol.divisorFromBase == Self.tenToThe(SOLANA.Solana.sol.decimals))
        #expect(SolanaContract.Units.defaultDisplayUnits == .sol)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(SolanaContract.Units.lamport.divisorFromBase == Self.tenToThe(0))
        #expect(SolanaContract.Units.chainBaseUnits == .lamport)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try SolanaChain.default.contract(for: "83astBRguLMdt2h5U1Tpdq5tjFoJ6noeGwaY3mDLVcri").address == "83astBRguLMdt2h5U1Tpdq5tjFoJ6noeGwaY3mDLVcri")
    }

    @Test(arguments: ["83astBRguLMdt2h5U1Tpdq5tjFoJ6noeGwaY3mDLVcr0", "83astBRguLMdt2h5U1Tpdq5tj", "0x00000000000000000000000000000000000000a1"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try SolanaChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try SolanaChain.default.contract(for: "83astBRguLMdt2h5U1Tpdq5tjFoJ6noeGwaY3mDLVcri")
        let decoded: SolanaContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == SolanaChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(SolanaChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? SolanaContract)
        #expect(contract == SolanaChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: SolanaChain.default.id + ":" + "83astBRguLMdt2h5U1Tpdq5tjFoJ6noeGwaY3mDLVcri")
        let contract = try #require(BlockChains.contract(of: account) as? SolanaContract)
        #expect(contract.address == "83astBRguLMdt2h5U1Tpdq5tjFoJ6noeGwaY3mDLVcri")
    }

    /// A generated token on the chain, from CoinGecko's recorded detail: its contract through the bridge, its
    /// decimals in the shared statement
    @Test func theGeneratedUsdCoinIsItsContractAtItsDecimals() throws {
        let token = SOLANA.Solana.usdCoin
        let contract = try #require(BlockChains.contract(of: token.instance) as? SolanaContract)
        #expect(contract.address == "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v")
        #expect(try AssetRegistry.shared.asset(of: token.instance) == .usdc)
        #expect(try AssetRegistry.shared.decimals(of: token.instance) == 6)
    }

    /// A generated token on the chain, from CoinGecko's recorded detail: its contract through the bridge, its
    /// decimals in the shared statement
    @Test func theGeneratedTetherIsItsContractAtItsDecimals() throws {
        let token = SOLANA.Solana.tether
        let contract = try #require(BlockChains.contract(of: token.instance) as? SolanaContract)
        #expect(contract.address == "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB")
        #expect(try AssetRegistry.shared.asset(of: token.instance) == .usdt)
        #expect(try AssetRegistry.shared.decimals(of: token.instance) == 6)
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "solana", by: .coinGecko) == SolanaChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "solana")?.chainId == SolanaChain.default.id)
    }

    @Test func coinMarketCapsRowLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "Solana", by: .coinMarketCap) == SolanaChain.default.id)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(SolanaChain.default.scanner.userReadableName == "Solana RPC")
    }

    /// The recorded `getBalance` of the docs' example account: 1,000,000 lamports, 0.001 SOL at the declared 9
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: SolanaRPC.Response<SolanaRPC.BalanceResponse> = try CoinGeckoRecorded.data("Solana/getBalance.json").fromJSON()
        let amount = try response.value().amount()
        #expect(amount.quantity == 1_000_000)
        #expect(amount.currency == SolanaChain.default.mainContract)
        #expect(amount.value() == 0.001)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 9)
    }

    /// The recorded `getSignaturesForAddress`: three signatures, the newest failed
    @Test func theRecordedSignaturesDecode() throws {
        let response: SolanaRPC.Response<[SolanaRPC.SignatureResponse]> = try CoinGeckoRecorded.data("Solana/getSignaturesForAddress.json").fromJSON()
        let signatures = try response.value()
        #expect(signatures.count == 3)
        #expect(signatures.map(\.failed) == [true, false, false])
        #expect(signatures[1].signature.hasPrefix("5qyWG36F"))
    }

    /// The recorded `getTransaction` of the second signature, for the account: 1,000,000 lamports in from the fee
    /// payer, at SOL's decimals
    @Test func theRecordedTransactionMapsToTheCoinForTheAccount() throws {
        let response: SolanaRPC.Response<SolanaRPC.TransactionResponse> = try CoinGeckoRecorded.data("Solana/getTransaction.json").fromJSON()
        let account = try SolanaChain.default.contract(for: "83astBRguLMdt2h5U1Tpdq5tjFoJ6noeGwaY3mDLVcri")
        let transactions = try response.value().cryptoTransactions(signature: "5qyWG36F", forAccount: account)
        try #require(transactions.count == 1)
        let read = Self.reading(transactions[0], as: SolanaContract.self)
        #expect(read.quantity == 1_000_000)
        #expect(read.currency == SolanaChain.default.mainContract)
        #expect(read.from == "7y1nkKdE6oLFaYYtz7rncdjPvMxa7EjZvjfctUNbsDCM")
        #expect(read.to == "83astBRguLMdt2h5U1Tpdq5tjFoJ6noeGwaY3mDLVcri")
        #expect(read.successful)
        #expect(read.timeStamp == Date(timeIntervalSince1970: 1_717_019_931))
    }

    /// `loadTransactions(from:)` reads the whole recorded answer: the payer's SOL out, its fee beside, and the account's in
    @Test func loadTransactionsReadsTheRecordedAnswer() throws {
        let transactions = try SolanaChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("Solana/getTransaction.json"))
        try #require(transactions.count == 2)
        let reads = transactions.map { Self.reading($0, as: SolanaContract.self) }
        #expect(reads.map(\.quantity) == [1_065_000, 1_000_000])
        #expect(reads.map(\.fee) == [65_000, nil])
        #expect(reads.allSatisfy { $0.hash.hasPrefix("5qyWG36F") })
    }

    /// CoinMarketCap's row lands on the chain; a token whose address the chain refuses is left out of the list, never
    /// failing the whole list
    @Test func anAggregatorsTokenTheChainRefusesIsLeftOut() throws {
        let listing = """
        {
          "status": { "timestamp": "2026-10-07T00:00:00.000Z", "error_code": 0, "error_message": null,
                      "elapsed": 1, "credit_count": 1 },
          "data": [
            { "id": 3408, "name": "USDC", "symbol": "USDC", "slug": "usd-coin", "is_active": 1,
              "first_historical_data": "2018-10-08T00:00:00.000Z",
              "platform": { "id": 5426, "name": "Solana", "symbol": "SOL", "slug": "solana",
                            "token_address": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v" } },
            { "id": 1, "name": "Refused", "symbol": "NOPE", "slug": "refused", "is_active": 1,
              "first_historical_data": "2018-10-08T00:00:00.000Z",
              "platform": { "id": 5426, "name": "Solana", "symbol": "SOL", "slug": "solana",
                            "token_address": "0x0" } }
          ]
        }
        """
        let response = try JSONDecoder().decode(CurrencyMapResponse.self, from: Data(listing.utf8))
        #expect(try response.tokens(for: SolanaContract.self).map(\.contractAddress.address) == ["EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"])
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let usdc = try #require(BlockChains.contract(of: SOLANA.Solana.usdCoin.instance) as? SolanaContract)
        let account = try SolanaChain.default.contract(for: "83astBRguLMdt2h5U1Tpdq5tjFoJ6noeGwaY3mDLVcri")
        await #expect(throws: SolanaRPCResponseError.self) {
            try await SolanaChain.default.scanner.getBalance(forToken: usdc, forAccount: account)
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
