// NervosChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Nervos:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct NervosChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(NervosChain.default.id == "ckb:mainnet")
        #expect(NervosChain.default.id == CKB.Nervos.chainId)
        let instance = try AssetInstance(validating: NervosChain.default.id + ":" + "shape")
        #expect(instance.chainId == NervosChain.default.id)
    }

    /// CAIP-2's shape: the namespace, 3 to 8 of `[-a-z0-9]`; the reference, 1 to 32 of `[-_a-zA-Z0-9]`
    @Test func theIdIsShapedAsCAIP2() {
        let parts = NervosChain.default.id.split(separator: ":")
        #expect(parts.count == 2)
        #expect((3...8).contains(parts[0].count))
        #expect(parts[0].allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") })
        #expect((1...32).contains(parts[1].count))
        #expect(parts[1].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
    }

    /// CAIP's registry holds no `ckb` (read 2026-10-07), so the library owns the namespace in its own table
    @Test func theNamespaceIsTheLibrarys() {
        #expect(CKB.namespace == "ckb")
        #expect(AssetRegistry.ownedNamespaces.contains(CKB.namespace))
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(NervosChain.default.mainContract.isChainToken)
        #expect(NervosChain.default.mainContract.address == "ckb")
        #expect(AssetInstance(NervosChain.default.mainContract).id == CKB.Nervos.ckb.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(NervosChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(CKB.Nervos.ckb.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(CKB.Nervos.ckb))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(NervosChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == CKB.Nervos.ckb)
        #expect(declaration.symbol.text == "CKB")
        #expect(declaration.tokenName == "Nervos Network")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(NervosContract.Units.ckb.divisorFromBase == Self.tenToThe(CKB.Nervos.ckb.decimals))
        #expect(NervosContract.Units.defaultDisplayUnits == .ckb)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(NervosContract.Units.shannon.divisorFromBase == Self.tenToThe(0))
        #expect(NervosContract.Units.chainBaseUnits == .shannon)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as the chain writes it
    @Test(arguments: ["ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqdnnw7qkdnnclfkg59uzn8umtfd2kwxceqxwquc4", "ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqtlf58l4xqymd2y75x5akargpkg9hmvgqgtez5cz", "ckb1qyqrdsefa43s6m882pcj53m4gdnj4k440axqdt9rtd"])
    func aWellFormedAddressIsKept(_ address: String) throws {
        #expect(try NervosChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["CKB1QZDA0CR08M85HC8JLNFP3ZER7XULEJYWT49KT2RR0VTHYWAA50XWSQDNNW7QKDNNCLFKG59UZN8UMTFD2KWXCEQXWQUC4", "ckt1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqdnnw7qkdnnclfkg59uzn8umtfd2kwxceqxwquc4", "ckb1qzda0cr08m85hc8jbnfp3zer7xulejywt49kt2rr0vthywaa50xwsqdnnw7qkdnnclfkg59uzn8umtfd2kwxceqxwquc4", "ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try NervosChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try NervosChain.default.contract(for: "ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqdnnw7qkdnnclfkg59uzn8umtfd2kwxceqxwquc4")
        let decoded: NervosContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == NervosChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(NervosChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? NervosContract)
        #expect(contract == NervosChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: NervosChain.default.id + ":" + "ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqdnnw7qkdnnclfkg59uzn8umtfd2kwxceqxwquc4")
        let contract = try #require(BlockChains.contract(of: account) as? NervosContract)
        #expect(contract.address == "ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqdnnw7qkdnnclfkg59uzn8umtfd2kwxceqxwquc4")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko names no Nervos CKB platform (its `godwoken` platform is Godwoken, a layer two on Nervos, not this
    /// chain), so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(NervosChain.default.id) == false)
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "godwoken", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "godwoken") == nil)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(NervosChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(NervosChain.default.scanner.userReadableName == "CKB Explorer")
        #expect(CKBExplorer.endPoint.absoluteString == "https://mainnet-api.explorer.nervos.org/api/v1")
        #expect(CKBExplorer.mediaType == "application/vnd.api+json")
    }

    /// The recorded address of RFC 0021's example: no CKB now, at CKB's declared 8
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: CKBExplorer.AddressResponse = try CoinGeckoRecorded.data("Nervos/address.json").fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 0)
        #expect(amount.currency == NervosChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 8)
    }

    /// The recorded transactions: three sends, each the address's income in shannons, to the one output shown
    @Test func theRecordedTransactionsMapToTheCoin() throws {
        let account = try NervosChain.default.contract(for: "ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqdnnw7qkdnnclfkg59uzn8umtfd2kwxceqxwquc4")
        let transactions = try NervosChain.default.scanner.loadTransactions(
            from: CoinGeckoRecorded.data("Nervos/address-transactions.json"), forAccount: account
        )
        try #require(transactions.count == 3)
        let reads = transactions.map { Self.reading($0, as: NervosContract.self) }
        #expect(reads.map(\.quantity) == [11_126_422_108, 12_098_232_991, 12_303_097_695])
        #expect(reads.allSatisfy { $0.from == "ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqdnnw7qkdnnclfkg59uzn8umtfd2kwxceqxwquc4" && $0.fee == nil && $0.successful })
        #expect(reads[0].to == "ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsq0487l62x4sgm5ep848ya6x4snnxf0dgqqdhx4wp")
        #expect(reads[0].hash == "0xff3dacb737d27fb3493c265ac9f581ad764e7c77c64a691f0afad09162e60f2c")
        #expect(reads[0].timeStamp == Date(timeIntervalSince1970: TimeInterval(1_583_758_875_639) / 1000))
        #expect(reads.allSatisfy { $0.currency == NervosChain.default.mainContract && $0.type == "transfer" })
    }

    /// An explorer answer does not name the address it was asked about, so it is read only for an address
    @Test func transactionsAreNotReadWithoutTheirAddress() throws {
        #expect(throws: CKBExplorerResponseError.self) { try NervosChain.default.scanner.loadTransactions(from: Data("{}".utf8)) }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try NervosChain.default.contract(for: "ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqdnnw7qkdnnclfkg59uzn8umtfd2kwxceqxwquc4")
        let other = try NervosChain.default.contract(
            for: "ckb1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqtlf58l4xqymd2y75x5akargpkg9hmvgqgtez5cz"
        )
        await #expect(throws: CKBExplorerResponseError.self) {
            try await NervosChain.default.scanner.getBalance(forToken: other, forAccount: account)
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
