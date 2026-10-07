// KusamaChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Kusama:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct KusamaChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(KusamaChain.default.id == "polkadot:b0a8d493285c2df73290dfb7e61f870f")
        #expect(KusamaChain.default.id == POLKADOT.Kusama.chainId)
        let instance = try AssetInstance(validating: KusamaChain.default.id + ":" + "shape")
        #expect(instance.chainId == KusamaChain.default.id)
        #expect(KusamaChain.default.id.split(separator: ":").count == 2)
    }

    /// The polkadot form: 32 lower-case hex digits after `polkadot:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = KusamaChain.default.id.dropFirst("polkadot:".count)
        #expect(KusamaChain.default.id.hasPrefix("polkadot:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(KusamaChain.default.mainContract.isChainToken)
        #expect(KusamaChain.default.mainContract.address == "ksm")
        #expect(AssetInstance(KusamaChain.default.mainContract).id == POLKADOT.Kusama.ksm.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(KusamaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 12)
        #expect(POLKADOT.Kusama.ksm.decimals == 12)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(POLKADOT.Kusama.ksm))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(KusamaChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == POLKADOT.Kusama.ksm)
        #expect(declaration.symbol.text == "KSM")
        #expect(declaration.tokenName == "Kusama")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(KusamaContract.Units.ksm.divisorFromBase == Self.tenToThe(POLKADOT.Kusama.ksm.decimals))
        #expect(KusamaContract.Units.defaultDisplayUnits == .ksm)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(KusamaContract.Units.planck.divisorFromBase == Self.tenToThe(0))
        #expect(KusamaContract.Units.chainBaseUnits == .planck)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["F3opxRbN5ZbjJNU511Kj2TLuzFcDq9BGduA9TgiECafpg29", "HRkCrbmke2XeabJ5fxJdgXWpBRPkXWfWHY8eTeCKwDdf4k6", "CaKpMFfFVXQrRRNDtMxiiPeiYBCYikNzrBmpuZUvmdQKrUR"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try KusamaChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFsTB", "4smVWa6Hb7WhGh9zgqdAE86p5eZyj8BQJ9Uro4o2zidBnmfX", "5C4iA2und8WV6mbvTBYupm2eZwtxk3wCYUM2SFHXSyQuapGp", "F3opxRbN5ZbjJNU511Kj2TLuzFcDq9BGduA9TgiECafpg2", "F3opxRbN5ZbjJNU511Kj2TLuzFcDq9BGduA9TgiECafpg290"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try KusamaChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try KusamaChain.default.contract(for: "F3opxRbN5ZbjJNU511Kj2TLuzFcDq9BGduA9TgiECafpg29")
        let decoded: KusamaContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == KusamaChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(KusamaChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? KusamaContract)
        #expect(contract == KusamaChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: KusamaChain.default.id + ":" + "F3opxRbN5ZbjJNU511Kj2TLuzFcDq9BGduA9TgiECafpg29")
        let contract = try #require(BlockChains.contract(of: account) as? KusamaContract)
        #expect(contract.address == "F3opxRbN5ZbjJNU511Kj2TLuzFcDq9BGduA9TgiECafpg29")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's `kusama` platform, as its `polkadot` one, names Asset Hub's assets, not the relay chain's (no recorded coin is on it), so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(KusamaChain.default.id) == false)
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "kusama", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "kusama") == nil)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(KusamaChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsTheChainsSidecarReadWithNoUnwrap() {
        #expect(KusamaChain.default.scanner.userReadableName == "Substrate API Sidecar")
        #expect(KusamaChain.default.scanner.endPoint.absoluteString == "https://kusama-public-sidecar.parity-chains.parity.io")
    }

    /// The recorded balance of the treasury's account (`modl` and `py/trsry`), 25,641,247,275,644 planck free, at KSM's declared 12
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: SubstrateSidecar<KusamaContract>.BalanceInfoResponse = try CoinGeckoRecorded.data("Kusama/balance-info.json").fromJSON()
        let amount = try response.amount()
        #expect(response.tokenSymbol == "KSM")
        #expect(amount.quantity == 25_641_247_275_644)
        #expect(amount.currency == KusamaChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 12)
    }

    /// The sidecar lists no account's transactions: they throw, never an empty list
    @Test func transactionsThrow() async throws {
        let account = try KusamaChain.default.contract(for: "F3opxRbN5ZbjJNU511Kj2TLuzFcDq9BGduA9TgiECafpg29")
        await #expect(throws: SubstrateSidecarResponseError.self) {
            try await KusamaChain.default.scanner.getTransactions(forAccount: account)
        }
        #expect(throws: SubstrateSidecarResponseError.self) { try KusamaChain.default.scanner.loadTransactions(from: Data()) }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try KusamaChain.default.contract(for: "F3opxRbN5ZbjJNU511Kj2TLuzFcDq9BGduA9TgiECafpg29")
        let other = try KusamaChain.default.contract(for: "HRkCrbmke2XeabJ5fxJdgXWpBRPkXWfWHY8eTeCKwDdf4k6")
        await #expect(throws: SubstrateSidecarResponseError.self) {
            try await KusamaChain.default.scanner.getBalance(forToken: other, forAccount: account)
        }
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
