// EnjinChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Enjin Relaychain:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct EnjinChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(EnjinChain.default.id == "polkadot:d8761d3c88f26dc12875c00d3165f7d6")
        #expect(EnjinChain.default.id == POLKADOT.Enjin.chainId)
        let instance = try AssetInstance(validating: EnjinChain.default.id + ":" + "shape")
        #expect(instance.chainId == EnjinChain.default.id)
    }

    /// The polkadot form: 32 lower-case hex digits after `polkadot:`, the first half of the genesis hash Enjin's
    /// own node answered (`0xd8761d3c88f26dc12875c00d3165f7d67243d56fc85b4cf19937601a7916e5a9`)
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = EnjinChain.default.id.dropFirst("polkadot:".count)
        #expect(EnjinChain.default.id.hasPrefix("polkadot:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
        #expect("0xd8761d3c88f26dc12875c00d3165f7d67243d56fc85b4cf19937601a7916e5a9".dropFirst(2).hasPrefix(reference))
    }

    /// Its namespace is CAIP's own, so the library does not own it
    @Test func theNamespaceIsCAIPsNotTheLibrarys() {
        #expect(!AssetRegistry.ownedNamespaces.contains(POLKADOT.namespace))
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(EnjinChain.default.mainContract.isChainToken)
        #expect(EnjinChain.default.mainContract.address == "enj")
        #expect(AssetInstance(EnjinChain.default.mainContract).id == POLKADOT.Enjin.enj.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(EnjinChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 18)
        #expect(POLKADOT.Enjin.enj.decimals == 18)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(POLKADOT.Enjin.enj))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(EnjinChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == POLKADOT.Enjin.enj)
        #expect(declaration.symbol.text == "ENJ")
        #expect(declaration.tokenName == "Enjin Coin")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(EnjinContract.Units.enj.divisorFromBase == Self.tenToThe(POLKADOT.Enjin.enj.decimals))
        #expect(EnjinContract.Units.defaultDisplayUnits == .enj)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(EnjinContract.Units.planck.divisorFromBase == Self.tenToThe(0))
        #expect(EnjinContract.Units.chainBaseUnits == .planck)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as the chain writes it
    @Test(arguments: ["enD9wdMEaQa3MEDUc7dtsCC86JYGMN5JBE2NBRoMyC37dX4iA", "enAgTck4eHz1AMLXWGXFWBt4Q76BwgxuNxEeo7FEjtcAN2G4F"])
    func aWellFormedAddressIsKept(_ address: String) throws {
        #expect(try EnjinChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFsTB", "F3opxRbN5ZbjJNU511Kj2TLuzFcDq9BGduA9TgiECafpg29", "5C4iA2und8WV6mbvTBYupm2eZwtxk3wCYUM2SFHXSyQuapGp", "efP9c3HFEACXjjM1xgKRtWbyWA6TwxW5z8GysGmWGQTjCtDW6", "enD9wdMEaQa3MEDUc7dtsCC86JYGMN5JBE2NBRoMyC37dX4", "enD9wdMEaQa3MEDUc7dtsCC86JYGMN5JBE2NBRoMyC37dX4iA1"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try EnjinChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try EnjinChain.default.contract(for: "enD9wdMEaQa3MEDUc7dtsCC86JYGMN5JBE2NBRoMyC37dX4iA")
        let decoded: EnjinContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == EnjinChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(EnjinChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? EnjinContract)
        #expect(contract == EnjinChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: EnjinChain.default.id + ":" + "enD9wdMEaQa3MEDUc7dtsCC86JYGMN5JBE2NBRoMyC37dX4iA")
        let contract = try #require(BlockChains.contract(of: account) as? EnjinContract)
        #expect(contract.address == "enD9wdMEaQa3MEDUc7dtsCC86JYGMN5JBE2NBRoMyC37dX4iA")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko names no Enjin platform (its `enjincoin` coin is a token on Ethereum), so the table has no row for the
    /// chain
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(EnjinChain.default.id) == false)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(EnjinChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsTheNilScannerReadWithNoUnwrap() {
        #expect(EnjinChain.default.scanner.userReadableName == "No scanner")
    }

    /// Enjin documents no public sidecar or explorer API, so its scanner answers zero and no transactions
    @Test func theNilScannerAnswersZeroAndNoTransactions() async throws {
        let account = try EnjinChain.default.contract(for: "enD9wdMEaQa3MEDUc7dtsCC86JYGMN5JBE2NBRoMyC37dX4iA")
        #expect(try await EnjinChain.default.scanner.getBalance(forAccount: account).quantity == 0)
        #expect(try await EnjinChain.default.scanner.getTransactions(forAccount: account).isEmpty)
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
