// NearChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for NEAR:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct NearChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(NearChain.default.id == "near:mainnet")
        #expect(NearChain.default.id == NEAR.Near.chainId)
        let instance = try AssetInstance(validating: NearChain.default.id + ":" + "shape")
        #expect(instance.chainId == NearChain.default.id)
    }

    /// CAIP-2's shape: the namespace, 3 to 8 of `[-a-z0-9]`; the reference, 1 to 32 of `[-_a-zA-Z0-9]`
    @Test func theIdIsShapedAsCAIP2() {
        let parts = NearChain.default.id.split(separator: ":")
        #expect(parts.count == 2)
        #expect((3...8).contains(parts[0].count))
        #expect(parts[0].allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") })
        #expect((1...32).contains(parts[1].count))
        #expect(parts[1].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
    }

    /// CAIP's registry holds no `near` (read 2026-10-07), so the library owns the namespace in its own table
    @Test func theNamespaceIsTheLibrarys() {
        #expect(NEAR.namespace == "near")
        #expect(AssetRegistry.ownedNamespaces.contains(NEAR.namespace))
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(NearChain.default.mainContract.isChainToken)
        #expect(NearChain.default.mainContract.address == "near")
        #expect(AssetInstance(NearChain.default.mainContract).id == NEAR.Near.near.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(NearChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 24)
        #expect(NEAR.Near.near.decimals == 24)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(NEAR.Near.near))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(NearChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == NEAR.Near.near)
        #expect(declaration.symbol.text == "NEAR")
        #expect(declaration.tokenName == "NEAR Protocol")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(NearContract.Units.near.divisorFromBase == Self.tenToThe(NEAR.Near.near.decimals))
        #expect(NearContract.Units.defaultDisplayUnits == .near)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(NearContract.Units.yoctonear.divisorFromBase == Self.tenToThe(0))
        #expect(NearContract.Units.chainBaseUnits == .yoctonear)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as the chain writes it
    @Test(arguments: ["near", "wrap.near", "usdt.tether-token.near", "17208628f84f5d6ad33f0da3bbbeb27ffcb398eac501a31bd6ad2011e36133a1", "relayer.nearmobile.near", "a_b-c.near"])
    func aWellFormedAddressIsKept(_ address: String) throws {
        #expect(try NearChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["a", "Near", "wrap..near", "-near", "near-", "near.", "a--b.near", "wrap near", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "wrap.NEAR"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try NearChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try NearChain.default.contract(for: "near")
        let decoded: NearContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == NearChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(NearChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? NearContract)
        #expect(contract == NearChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: NearChain.default.id + ":" + "near")
        let contract = try #require(BlockChains.contract(of: account) as? NearContract)
        #expect(contract.address == "near")
    }

    /// A generated token on the chain, from CoinGecko's recorded detail: its contract through the bridge, its
    /// decimals in the shared statement
    @Test func theGeneratedUsdCoinIsItsContractAtItsDecimals() throws {
        let token = NEAR.Near.usdCoin
        let contract = try #require(BlockChains.contract(of: token.instance) as? NearContract)
        #expect(contract.address == "17208628f84f5d6ad33f0da3bbbeb27ffcb398eac501a31bd6ad2011e36133a1")
        #expect(try AssetRegistry.shared.asset(of: token.instance) == .usdc)
        #expect(try AssetRegistry.shared.decimals(of: token.instance) == 6)
    }

    /// A generated token on the chain, a named account: its contract through the bridge, its decimals in the shared
    /// statement
    @Test func theGeneratedTetherIsItsContractAtItsDecimals() throws {
        let token = NEAR.Near.tether
        let contract = try #require(BlockChains.contract(of: token.instance) as? NearContract)
        #expect(contract.address == "usdt.tether-token.near")
        #expect(try AssetRegistry.shared.asset(of: token.instance) == .usdt)
        #expect(try AssetRegistry.shared.decimals(of: token.instance) == 6)
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "near-protocol", by: .coinGecko) == NearChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "near-protocol")?.chainId == NearChain.default.id)
    }

    /// CoinGecko's `aurora` platform is Aurora, an EVM chain on NEAR (chain 1313161554), not this chain, so it lands
    /// nowhere
    @Test func coinGeckosOtherPlatformIsNoAdmittedChain() {
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "aurora", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "aurora") == nil)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(NearChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(NearChain.default.scanner.userReadableName == "NEAR RPC")
        #expect(NearRPC.endPoint.absoluteString == "https://rpc.mainnet.near.org")
        #expect(NearRPC.indexer.absoluteString == "https://api.nearblocks.io")
    }

    /// The recorded `view_account` of `near`, the protocol's top-level registrar: 69,272.747797664265084068221638
    /// NEAR in yoctoNEAR, at NEAR's declared 24
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: NearRPC.Response<NearRPC.ViewAccountResponse> = try CoinGeckoRecorded.data("Near/view-account.json").fromJSON()
        let amount = try response.value().amount()
        #expect(amount.quantity == 69_272_747_797_664_265_084_068_221_638)
        #expect(amount.currency == NearChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 24)
    }

    /// NOT A RECORDING: an error in the shape NEAR's RPC documents for an unknown account, thrown in its words
    @Test func anErrorIsThrownInTheNodesWords() throws {
        let documented = #"{"jsonrpc":"2.0","error":{"name":"HANDLER_ERROR","cause":{"name":"UNKNOWN_ACCOUNT","info":{}},"code":-32000,"message":"Server error"},"id":"fos"}"#
        let response: NearRPC.Response<NearRPC.ViewAccountResponse> = try Data(documented.utf8).fromJSON()
        #expect(throws: NearRPCResponseError.self) { try response.value() }
    }

    /// The recorded NearBlocks receipts of `near`: three of one account-creation transaction, each deposit 0, each
    /// fee the tokens its outcome burnt (one written in exponent form, read exactly)
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let transactions = try NearChain.default.scanner.loadTransactions(from: CoinGeckoRecorded.data("Near/txns.json"))
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: NearContract.self) }
        #expect(reads.map(\.quantity) == [0, 0, 0])
        #expect(reads.map(\.fee) == [126_204_743_685_800_000_000, 7_032_494_768_750_000_000_000, 253_167_121_630_300_000_000])
        #expect(reads.map(\.from) == ["near", "near", "relayer.nearmobile.near"])
        #expect(reads.map(\.to) == ["near", "samertheharir.near", "near"])
        #expect(reads.map(\.type) == ["FUNCTION_CALL", "CREATE_ACCOUNT", "FUNCTION_CALL"])
        #expect(reads.allSatisfy { $0.hash == "6g5szqqq2fpRug6RRDusm1iYsJB8tPVGb9YhdezDPApK" && $0.successful })
        #expect(reads.allSatisfy { $0.currency == NearChain.default.mainContract })
        #expect(transactions.map(\.transactionId) == [
            "6Er3yXghoh6DRUbW5Wai5zkrkUouDHuBQGrFbhosh2nx", "284gjUVCGLnuLvjKiL661rTqbqBNHHfkoW4BngLs3pmT",
            "BkLdqLDsjUjBToxoT7UCPiZeQ5Xb2aMcUxzoKDXG5Wuo"
        ])
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: TimeInterval(1_791_382_807_903) / 1000))
    }

    /// NearBlocks writes large counts as JSON numbers in exponent form; each is read exactly, and a fraction of a
    /// yoctoNEAR is no count
    @Test func aCountInExponentFormIsReadExactly() throws {
        #expect(NearRPC.yocto(try #require(Decimal(string: "7.03249476875e+21"))) == 7_032_494_768_750_000_000_000)
        #expect(NearRPC.yocto(try #require(Decimal(string: "0.5"))) == nil)
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try NearChain.default.contract(for: "near")
        let tether = try NearChain.default.contract(for: "usdt.tether-token.near")
        await #expect(throws: NearRPCResponseError.self) {
            try await NearChain.default.scanner.getBalance(forToken: tether, forAccount: account)
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
