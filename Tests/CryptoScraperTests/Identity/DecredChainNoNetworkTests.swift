// DecredChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Decred:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct DecredChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(DecredChain.default.id == "dcr:mainnet")
        #expect(DecredChain.default.id == DCR.Decred.chainId)
        let instance = try AssetInstance(validating: DecredChain.default.id + ":" + "shape")
        #expect(instance.chainId == DecredChain.default.id)
    }

    /// CAIP-2's shape: the namespace, 3 to 8 of `[-a-z0-9]`; the reference, 1 to 32 of `[-_a-zA-Z0-9]`
    @Test func theIdIsShapedAsCAIP2() {
        let parts = DecredChain.default.id.split(separator: ":")
        #expect(parts.count == 2)
        #expect((3...8).contains(parts[0].count))
        #expect(parts[0].allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") })
        #expect((1...32).contains(parts[1].count))
        #expect(parts[1].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
    }

    /// CAIP's registry holds no `dcr` (read 2026-10-07), so the library owns the namespace in its own table
    @Test func theNamespaceIsTheLibrarys() {
        #expect(DCR.namespace == "dcr")
        #expect(AssetRegistry.ownedNamespaces.contains(DCR.namespace))
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(DecredChain.default.mainContract.isChainToken)
        #expect(DecredChain.default.mainContract.address == "dcr")
        #expect(AssetInstance(DecredChain.default.mainContract).id == DCR.Decred.dcr.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(DecredChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 8)
        #expect(DCR.Decred.dcr.decimals == 8)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(DCR.Decred.dcr))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(DecredChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == DCR.Decred.dcr)
        #expect(declaration.symbol.text == "DCR")
        #expect(declaration.tokenName == "Decred")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(DecredContract.Units.dcr.divisorFromBase == Self.tenToThe(DCR.Decred.dcr.decimals))
        #expect(DecredContract.Units.defaultDisplayUnits == .dcr)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(DecredContract.Units.atom.divisorFromBase == Self.tenToThe(0))
        #expect(DecredContract.Units.chainBaseUnits == .atom)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as the chain writes it
    @Test(arguments: ["Dcur2mcGjmENx4DhNqDctW5wJCVyT3Qeqkx", "DsR4EaQLoT7UumUKDfXhkUN3ic7ac1Xoc2K", "DeYEw4voajLesbbrSt73YxMLYTyLRK6Xnpy", "DSU6qXfrwRvkb4bfr9X3zQbAwaqc7x6tmp3"])
    func aWellFormedAddressIsKept(_ address: String) throws {
        #expect(try DecredChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["DkM6N64GFHYBsyqoTQjXyhhx8P4Mys4VToG1wwqCRmobz3Z4mW4mV", "TsR7TZXrCFAb289g349ru3PKJi5WAjgQtur", "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa", "Dcur2mcGjmENx4DhNqDctW5wJCVyT3Qeqk", "Dcur2mcGjmENx4DhNqDctW5wJCVyT3Qeqk0"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try DecredChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try DecredChain.default.contract(for: "Dcur2mcGjmENx4DhNqDctW5wJCVyT3Qeqkx")
        let decoded: DecredContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == DecredChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(DecredChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? DecredContract)
        #expect(contract == DecredChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: DecredChain.default.id + ":" + "Dcur2mcGjmENx4DhNqDctW5wJCVyT3Qeqkx")
        let contract = try #require(BlockChains.contract(of: account) as? DecredContract)
        #expect(contract.address == "Dcur2mcGjmENx4DhNqDctW5wJCVyT3Qeqkx")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko names no Decred platform, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(DecredChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(DecredChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(DecredChain.default.scanner.userReadableName == "dcrdata")
        #expect(Dcrdata.endPoint.absoluteString == "https://dcrdata.decred.org/api")
    }

    /// The recorded totals of the organization's address (dcrd's mainnet parameters): 40,472.13133726 DCR unspent, a
    /// JSON number read exactly, in atoms at DCR's declared 8
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: Dcrdata.TotalsResponse = try CoinGeckoRecorded.data("Decred/totals.json").fromJSON()
        let amount = try response.amount()
        #expect(amount.quantity == 4_047_213_133_726)
        #expect(amount.currency == DecredChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 8)
    }

    /// NOT A RECORDING: a total finer than an atom is no count of atoms
    @Test func aTotalFinerThanAnAtomIsRefused() throws {
        let shaped = #"{"address":"x","dcr_spent":0,"dcr_unspent":0.000000001}"#
        let response: Dcrdata.TotalsResponse = try Data(shaped.utf8).fromJSON()
        #expect(throws: DcrdataResponseError.self) { try response.amount() }
    }

    /// The raw transactions read answered 422 when recorded, so the scanner says so rather than answer none
    @Test func theTransactionsAreNotReadAndSaySo() async throws {
        let account = try DecredChain.default.contract(for: "Dcur2mcGjmENx4DhNqDctW5wJCVyT3Qeqkx")
        await #expect(throws: DcrdataResponseError.self) {
            try await DecredChain.default.scanner.getTransactions(forAccount: account)
        }
        #expect(throws: DcrdataResponseError.self) { try DecredChain.default.scanner.loadTransactions(from: Data("[]".utf8)) }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try DecredChain.default.contract(for: "Dcur2mcGjmENx4DhNqDctW5wJCVyT3Qeqkx")
        let other = try DecredChain.default.contract(for: "DsR4EaQLoT7UumUKDfXhkUN3ic7ac1Xoc2K")
        await #expect(throws: DcrdataResponseError.self) {
            try await DecredChain.default.scanner.getBalance(forToken: other, forAccount: account)
        }
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
