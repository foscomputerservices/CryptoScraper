// StellarChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Stellar: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct StellarChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(StellarChain.default.id == "stellar:pubnet")
        #expect(StellarChain.default.id == STELLAR.Stellar.chainId)
        let instance = try AssetInstance(validating: StellarChain.default.id + ":" + "shape")
        #expect(instance.chainId == StellarChain.default.id)
        #expect(StellarChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(StellarChain.default.mainContract.isChainToken)
        #expect(StellarChain.default.mainContract.address == "xlm")
        #expect(AssetInstance(StellarChain.default.mainContract).id == STELLAR.Stellar.xlm.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(StellarChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 7)
        #expect(STELLAR.Stellar.xlm.decimals == 7)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(STELLAR.Stellar.xlm))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(StellarChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == STELLAR.Stellar.xlm)
        #expect(declaration.symbol.text == "XLM")
        #expect(declaration.tokenName == "Stellar")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(StellarContract.Units.xlm.divisorFromBase == Self.tenToThe(STELLAR.Stellar.xlm.decimals))
        #expect(StellarContract.Units.defaultDisplayUnits == .xlm)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(StellarContract.Units.stroop.divisorFromBase == Self.tenToThe(0))
        #expect(StellarContract.Units.chainBaseUnits == .stroop)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try StellarChain.default.contract(for: "GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWN7").address == "GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWN7")
    }

    @Test(arguments: ["gaazi4tcr3ty5ojhctjc2a4qsy6cjwjh5iajtgkin2er7lbnvkoccwn7", "MAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWN7", "GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWN"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try StellarChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try StellarChain.default.contract(for: "GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWN7")
        let decoded: StellarContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == StellarChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(StellarChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? StellarContract)
        #expect(contract == StellarChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: StellarChain.default.id + ":" + "GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWN7")
        let contract = try #require(BlockChains.contract(of: account) as? StellarContract)
        #expect(contract.address == "GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWN7")
    }

    /// A generated token on the chain, from CoinGecko's recorded detail: its contract through the bridge, its
    /// decimals in the shared statement
    @Test func theGeneratedUsdCoinIsItsContractAtItsDecimals() throws {
        let token = STELLAR.Stellar.usdCoin
        let contract = try #require(BlockChains.contract(of: token.instance) as? StellarContract)
        #expect(contract.address == "CCW67TSZV3SSS2HXMBQ5JFGCKJNXKZM7UQUWUZPUTHXSTZLEO7SJMI75")
        #expect(try AssetRegistry.shared.asset(of: token.instance) == .usdc)
        #expect(try AssetRegistry.shared.decimals(of: token.instance) == 7)
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "stellar", by: .coinGecko) == StellarChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "stellar")?.chainId == StellarChain.default.id)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(StellarChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(StellarChain.default.scanner.userReadableName == "Horizon")
    }

    /// The recorded account: its native balance "99.4338371", 994,338,371 stroops at XLM's declared 7
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: Horizon.AccountResponse = try CoinGeckoRecorded.data("Stellar/account.json").fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 994_338_371)
        #expect(amount.currency == StellarChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 7)
    }

    /// Horizon's decimal strings read exactly, never through a `Double`
    @Test func anAmountReadsInStroopsExactly() {
        #expect(Horizon.stroops("0.0000001") == 1)
        #expect(Horizon.stroops("99.4338371") == 994_338_371)
        #expect(Horizon.stroops("12") == 120_000_000)
        #expect(Horizon.stroops("1.00000001") == nil)
        #expect(Horizon.stroops("one") == nil)
    }

    /// The recorded payments: three payments of one stroop each, in XLM, to the account
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let transactions = try StellarChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("Stellar/payments.json"))
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: StellarContract.self) }
        #expect(reads.map(\.quantity) == [1, 1, 1])
        #expect(reads.allSatisfy { $0.currency == StellarChain.default.mainContract && $0.successful })
        #expect(reads.allSatisfy { $0.from == "GAKPQTQOKFN6PLPLBOYSPZ2K52FGK5VVTSFIFAYJXDJ5WUHEWZR6DCXR" })
        #expect(reads.allSatisfy { $0.to == "GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWN7" })
        #expect(reads[0].hash == "3089be1f56a4c0d5773f5dd8334414c1c53f8c030c412bee718df785d1fc3f1e")
        #expect(reads[0].timeStamp == ISO8601DateFormatter().date(from: "2026-10-03T20:35:32Z"))
    }

    /// A classic asset as CoinGecko writes it, `<code>-<issuer>`, is a contract on the chain, kept as given
    @Test func aClassicAssetInCoinGeckosFormIsAContract() throws {
        let asset = "AFR-GBX6YI45VU7WNAAKA3RBFDR3I3UKNFHTJPQ5F6KOOKSGYIAM4TRQN54W"
        #expect(try StellarChain.default.contract(for: asset).address == asset)
        #expect(throws: BlockChainError.self) { try StellarChain.default.contract(for: "TOOLONGASSETCODE-GBX6YI45VU7WNAAKA3RBFDR3I3UKNFHTJPQ5F6KOOKSGYIAM4TRQN54W") }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let usdc = try #require(BlockChains.contract(of: STELLAR.Stellar.usdCoin.instance) as? StellarContract)
        let account = try StellarChain.default.contract(for: "GAAZI4TCR3TY5OJHCTJC2A4QSY6CJWJH5IAJTGKIN2ER7LBNVKOCCWN7")
        await #expect(throws: HorizonResponseError.self) {
            try await StellarChain.default.scanner.getBalance(forToken: usdc, forAccount: account)
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
