// ConfluxChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Conflux: its
/// id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct ConfluxChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(ConfluxChain.default.id == "conflux:cfx")
        #expect(ConfluxChain.default.id == CONFLUX.Conflux.chainId)
        let instance = try AssetInstance(validating: ConfluxChain.default.id + ":" + "shape")
        #expect(instance.chainId == ConfluxChain.default.id)
        #expect(ConfluxChain.default.id.split(separator: ":").count == 2)
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(ConfluxChain.default.mainContract.isChainToken)
        #expect(ConfluxChain.default.mainContract.address == "cfx")
        #expect(AssetInstance(ConfluxChain.default.mainContract).id == CONFLUX.Conflux.cfx.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(ConfluxChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 18)
        #expect(CONFLUX.Conflux.cfx.decimals == 18)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(CONFLUX.Conflux.cfx))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(ConfluxChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == CONFLUX.Conflux.cfx)
        #expect(declaration.symbol.text == "CFX")
        #expect(declaration.tokenName == "Conflux")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(ConfluxContract.Units.cfx.divisorFromBase == Self.tenToThe(CONFLUX.Conflux.cfx.decimals))
        #expect(ConfluxContract.Units.defaultDisplayUnits == .cfx)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(ConfluxContract.Units.drip.divisorFromBase == Self.tenToThe(0))
        #expect(ConfluxContract.Units.chainBaseUnits == .drip)
    }

    // MARK: The addresses

    @Test func aWellFormedAddressIsKeptAsGiven() throws {
        #expect(try ConfluxChain.default.contract(for: "aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg").address == "aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg")
    }

    @Test(arguments: ["cfxtest:aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg", "Cfx:aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg", "cfx:aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4x", "cfx:iarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg", "0x1ecde7223747601823f7535d7968ba98b4881e09"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.self) { try ConfluxChain.default.contract(for: address) }
    }

    /// CAIP-10 writes a core space account `conflux:cfx:<body>`: the address's body in lower case, the network prefix and the optional fields dropped
    @Test func anAddressIsNormalizedByTheChain() throws {
        #expect(try ConfluxChain.default.contract(for: "cfx:aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg").address == "aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg")
        #expect(try ConfluxChain.default.contract(for: "cfx:type.user:aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg").address == "aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg")
        #expect(try ConfluxChain.default.contract(for: "CFX:TYPE.USER:AARC9ABYCUE0HHZGYRR53M6CXEDGCCRMMYYBJGH4XG").address == "aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg")
        #expect(try ConfluxChain.default.contract(for: "CFX:AARC9ABYCUE0HHZGYRR53M6CXEDGCCRMMYYBJGH4XG").address == "aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg")
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try ConfluxChain.default.contract(for: "aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg")
        let decoded: ConfluxContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == ConfluxChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(ConfluxChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? ConfluxContract)
        #expect(contract == ConfluxChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: ConfluxChain.default.id + ":" + "aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg")
        let contract = try #require(BlockChains.contract(of: account) as? ConfluxContract)
        #expect(contract.address == "aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's `conflux` platform states chain 1030, Conflux eSpace, the EVM space: it is not the core space, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(ConfluxChain.default.id) == false)
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "conflux", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "conflux") == nil)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(ConfluxChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(ConfluxChain.default.scanner.userReadableName == "Conflux RPC")
    }

    /// The recorded docs' example address: 0x259e2effca6c8, 661,781,177,214,664 drip, at CFX's declared 18
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: ConfluxRPC.Response<String> = try CoinGeckoRecorded.data("Conflux/cfx_getBalance.json").fromJSON()
        let amount = try ConfluxRPC.balance(response.value())
        #expect(amount.quantity == 661_781_177_214_664)
        #expect(amount.currency == ConfluxChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 18)
    }

    /// The node lists no address's transactions and ConfluxScan's list moved, so the scanner says so
    @Test func theTransactionsAreNotReadAndSaySo() async throws {
        let account = try ConfluxChain.default.contract(for: "cfx:aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg")
        await #expect(throws: ConfluxRPCResponseError.self) {
            try await ConfluxChain.default.scanner.getTransactions(forAccount: account)
        }
        #expect(throws: ConfluxRPCResponseError.self) { try ConfluxChain.default.scanner.loadTransactions(from: Data("{}".utf8)) }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try ConfluxChain.default.contract(for: "cfx:aarc9abycue0hhzgyrr53m6cxedgccrmmyybjgh4xg")
        await #expect(throws: ConfluxRPCResponseError.self) {
            try await ConfluxChain.default.scanner.getBalance(forToken: account, forAccount: account)
        }
    }


    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
