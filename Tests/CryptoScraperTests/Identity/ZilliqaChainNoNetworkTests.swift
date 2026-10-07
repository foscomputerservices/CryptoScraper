// ZilliqaChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Zilliqa:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct ZilliqaChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(ZilliqaChain.default.id == "zil:mainnet")
        #expect(ZilliqaChain.default.id == ZIL.Zilliqa.chainId)
        let instance = try AssetInstance(validating: ZilliqaChain.default.id + ":" + "shape")
        #expect(instance.chainId == ZilliqaChain.default.id)
    }

    /// CAIP-2's shape: the namespace, 3 to 8 of `[-a-z0-9]`; the reference, 1 to 32 of `[-_a-zA-Z0-9]`
    @Test func theIdIsShapedAsCAIP2() {
        let parts = ZilliqaChain.default.id.split(separator: ":")
        #expect(parts.count == 2)
        #expect((3...8).contains(parts[0].count))
        #expect(parts[0].allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") })
        #expect((1...32).contains(parts[1].count))
        #expect(parts[1].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
    }

    /// CAIP's registry holds no `zil` (read 2026-10-07), so the library owns the namespace in its own table
    @Test func theNamespaceIsTheLibrarys() {
        #expect(ZIL.namespace == "zil")
        #expect(AssetRegistry.ownedNamespaces.contains(ZIL.namespace))
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(ZilliqaChain.default.mainContract.isChainToken)
        #expect(ZilliqaChain.default.mainContract.address == "zil")
        #expect(AssetInstance(ZilliqaChain.default.mainContract).id == ZIL.Zilliqa.zil.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(ZilliqaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 12)
        #expect(ZIL.Zilliqa.zil.decimals == 12)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(ZIL.Zilliqa.zil))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(ZilliqaChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == ZIL.Zilliqa.zil)
        #expect(declaration.symbol.text == "ZIL")
        #expect(declaration.tokenName == "Zilliqa")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(ZilliqaContract.Units.zil.divisorFromBase == Self.tenToThe(ZIL.Zilliqa.zil.decimals))
        #expect(ZilliqaContract.Units.defaultDisplayUnits == .zil)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(ZilliqaContract.Units.qa.divisorFromBase == Self.tenToThe(0))
        #expect(ZilliqaContract.Units.chainBaseUnits == .qa)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as the chain writes it
    @Test(arguments: ["zil1rmhufazn2w09aeejkj0tg7fty6xz7wggup2tsh", "zil1qypqxpq9qcrsszg2pvxq6rs0zqg3yyc5f99mqr"])
    func aWellFormedAddressIsKept(_ address: String) throws {
        #expect(try ZilliqaChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["zil1rmhufazn2w09aeejkj0tg7fty6xz7wggup2tsq", "ZIL1RMHUFAZN2W09AEEJKJ0TG7FTY6XZ7WGGUP2TSH", "1eefc4f453539e5ee732b49eb4792b268c2f3908", "0x1eefc4f453539e5ee732b49eb4792b268c2f390", "cosmos10d07y265gmmuvt4z0w9aw880jnsr700j6zn9kn", "zil1rmhufazn2w09aeejkj0tg7fty6xz7wggup2ts", "zil1bmhufazn2w09aeejkj0tg7fty6xz7wggup2tsh"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try ZilliqaChain.default.contract(for: address) }
    }

    /// An address in another form the chain accepts is written in its canonical form
    @Test(arguments: [("0x1eefc4f453539e5ee732b49eb4792b268c2f3908", "zil1rmhufazn2w09aeejkj0tg7fty6xz7wggup2tsh"), ("0x1EEFC4F453539E5EE732B49EB4792B268C2F3908", "zil1rmhufazn2w09aeejkj0tg7fty6xz7wggup2tsh")])
    func anAddressIsNormalizedByTheChain(_ given: String, _ canonical: String) throws {
        #expect(try ZilliqaChain.default.contract(for: given).address == canonical)
        #expect(try AssetInstance(ZilliqaChain.default.contract(for: given)).id == ZilliqaChain.default.id + ":" + canonical)
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try ZilliqaChain.default.contract(for: "zil1rmhufazn2w09aeejkj0tg7fty6xz7wggup2tsh")
        let decoded: ZilliqaContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == ZilliqaChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(ZilliqaChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? ZilliqaContract)
        #expect(contract == ZilliqaChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: ZilliqaChain.default.id + ":" + "zil1rmhufazn2w09aeejkj0tg7fty6xz7wggup2tsh")
        let contract = try #require(BlockChains.contract(of: account) as? ZilliqaContract)
        #expect(contract.address == "zil1rmhufazn2w09aeejkj0tg7fty6xz7wggup2tsh")
    }

    // MARK: The reference rows (design § 2.4)

    @Test func coinGeckosPlatformLandsOnTheChain() throws {
        #expect(try AssetRegistry.chainId(named: "zilliqa", by: .coinGecko) == ZilliqaChain.default.id)
        #expect(AssetImporter.admittedChain(platform: "zilliqa")?.chainId == ZilliqaChain.default.id)
    }

    /// CoinGecko's `zilliqa-evm` platform is Zilliqa 2.0's EVM side, `eip155:32769`, another chain id, not this chain,
    /// so it lands nowhere
    @Test func coinGeckosOtherPlatformIsNoAdmittedChain() {
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "zilliqa-evm", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "zilliqa-evm") == nil)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(ZilliqaChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(ZilliqaChain.default.scanner.userReadableName == "Zilliqa RPC")
        #expect(ZilliqaRPC.endPoint.absoluteString == "https://api.zilliqa.com")
    }

    /// The recorded `GetBalance` of the docs' example address: "Account is not created", which holds no ZIL
    @Test func theRecordedAnswerIsNoAccountAndReadsZero() throws {
        let response: ZilliqaRPC.BalanceResponse = try CoinGeckoRecorded.data("Zilliqa/balance.json").fromJSON()
        let amount = try response.amount()
        #expect(response.error?.message == "Account is not created")
        #expect(amount.quantity == 0)
        #expect(amount.currency == ZilliqaChain.default.mainContract)
    }

    /// NOT A RECORDING: the docs' example answer, `18446744073637511711` Qa, at ZIL's declared 12
    @Test func theDocumentedAnswerIsTheCoinAtItsDecimals() throws {
        let documented = #"{"id":"1","jsonrpc":"2.0","result":{"balance":"18446744073637511711","nonce":16}}"#
        let response: ZilliqaRPC.BalanceResponse = try Data(documented.utf8).fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 18_446_744_073_637_511_711)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 12)
    }

    /// NOT A RECORDING: any other error is thrown in the RPC's words
    @Test func anyOtherErrorIsThrown() throws {
        let shaped = #"{"id":"1","jsonrpc":"2.0","error":{"code":-8,"message":"Address size not appropriate"}}"#
        let response: ZilliqaRPC.BalanceResponse = try Data(shaped.utf8).fromJSON()
        #expect(throws: ZilliqaRPCResponseError.self) { try response.amount() }
    }

    /// The RPC is asked with the address's bytes in hex, the docs' form, read back from its bech32
    @Test func theRPCIsAskedWithTheAddressesBytes() throws {
        let bytes = try #require(ZilliqaContract.bytes(bech32: "zil1rmhufazn2w09aeejkj0tg7fty6xz7wggup2tsh"))
        #expect(bytes.map { String(format: "%02x", $0) }.joined() == "1eefc4f453539e5ee732b49eb4792b268c2f3908")
        #expect(ZilliqaContract.bech32(bytes) == "zil1rmhufazn2w09aeejkj0tg7fty6xz7wggup2tsh")
    }

    @Test func theTransactionsAreNotReadAndSaySo() async throws {
        let account = try ZilliqaChain.default.contract(for: "zil1rmhufazn2w09aeejkj0tg7fty6xz7wggup2tsh")
        await #expect(throws: ZilliqaRPCResponseError.self) {
            try await ZilliqaChain.default.scanner.getTransactions(forAccount: account)
        }
        #expect(throws: ZilliqaRPCResponseError.self) { try ZilliqaChain.default.scanner.loadTransactions(from: Data("{}".utf8)) }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try ZilliqaChain.default.contract(for: "zil1rmhufazn2w09aeejkj0tg7fty6xz7wggup2tsh")
        let token = try ZilliqaChain.default.contract(for: "zil1qypqxpq9qcrsszg2pvxq6rs0zqg3yyc5f99mqr")
        await #expect(throws: ZilliqaRPCResponseError.self) {
            try await ZilliqaChain.default.scanner.getBalance(forToken: token, forAccount: account)
        }
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
