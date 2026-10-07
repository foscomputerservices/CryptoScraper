// PolkadotChainNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
@testable import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 2.5 "What each new chain must provide" and § 6 "Each chain, before it is admitted", for Polkadot:
/// its id, its coin, its ladder, its addresses, its place among the chains, its reference rows and its scanner against
/// its recorded answers. No network.
@Suite struct PolkadotChainNoNetworkTests {
    // MARK: The id

    @Test func theIdIsPinnedToItsCAIP2String() throws {
        #expect(PolkadotChain.default.id == "polkadot:91b171bb158e2d3848fa23a9f1c25182")
        #expect(PolkadotChain.default.id == POLKADOT.Polkadot.chainId)
        let instance = try AssetInstance(validating: PolkadotChain.default.id + ":" + "shape")
        #expect(instance.chainId == PolkadotChain.default.id)
        #expect(PolkadotChain.default.id.split(separator: ":").count == 2)
    }

    /// The polkadot form: 32 lower-case hex digits after `polkadot:`
    @Test func theIdIsShapedAsTheNamespaceFormsIt() {
        let reference = PolkadotChain.default.id.dropFirst("polkadot:".count)
        #expect(PolkadotChain.default.id.hasPrefix("polkadot:"))
        #expect(reference.count == 32)
        #expect(reference.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: The coin

    @Test func theCoinIsItsDeclaredInstance() {
        #expect(PolkadotChain.default.mainContract.isChainToken)
        #expect(PolkadotChain.default.mainContract.address == "dot")
        #expect(AssetInstance(PolkadotChain.default.mainContract).id == POLKADOT.Polkadot.dot.instance.id)
    }

    @Test func theCoinIsDeclaredInTheSharedStatementAtItsDecimals() throws {
        let coin = AssetInstance(PolkadotChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: coin) == 10)
        #expect(POLKADOT.Polkadot.dot.decimals == 10)
        #expect(try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin)).instances
            .contains(POLKADOT.Polkadot.dot))
    }

    /// Its coin is an asset of its own, its home this chain
    @Test func theCoinIsTheHomeOfItsOwnAsset() throws {
        let coin = AssetInstance(PolkadotChain.default.mainContract)
        let declaration = try AssetRegistry.shared.declaration(of: AssetRegistry.shared.asset(of: coin))
        #expect(declaration.instances.first == POLKADOT.Polkadot.dot)
        #expect(declaration.symbol.text == "DOT")
        #expect(declaration.tokenName == "Polkadot")
    }

    // MARK: The ladder against the statement (design § 2.2)

    @Test func theWholeUnitIsTenToTheDeclaredDecimals() {
        #expect(PolkadotContract.Units.dot.divisorFromBase == Self.tenToThe(POLKADOT.Polkadot.dot.decimals))
        #expect(PolkadotContract.Units.defaultDisplayUnits == .dot)
    }

    @Test func theBaseUnitIsTenToTheZero() {
        #expect(PolkadotContract.Units.planck.divisorFromBase == Self.tenToThe(0))
        #expect(PolkadotContract.Units.chainBaseUnits == .planck)
    }

    // MARK: The addresses

    /// Each address form the chain writes is kept as given
    @Test(arguments: ["13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFsTB", "15rRgsWxz4H5LTnNGcCFsszfXD8oeAFd8QRsR6MbQE2f6XFF", "11JNArUumxYJcSQpbuxuroRZtcSMVLcy5WbYGt14SRkztH"])
    func aWellFormedAddressIsKeptAsGiven(_ address: String) throws {
        #expect(try PolkadotChain.default.contract(for: address).address == address)
    }

    @Test(arguments: ["F3opxRbN5ZbjJNU511Kj2TLuzFcDq9BGduA9TgiECafpg29", "5C4iA2und8WV6mbvTBYupm2eZwtxk3wCYUM2SFHXSyQuapGp", "13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFs", "13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFsT0", "0x6d6f646c70792f74727372790000000000000000000000000000000000000000"])
    func aMalformedAddressIsRefused(_ address: String) {
        #expect(throws: BlockChainError.malformedAddress(address)) { try PolkadotChain.default.contract(for: address) }
    }

    @Test func aContractRoundTripsThroughCodable() throws {
        let contract = try PolkadotChain.default.contract(for: "13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFsTB")
        let decoded: PolkadotContract = try contract.toJSON().fromJSON()
        #expect(decoded == contract)
    }

    // MARK: Its place among the chains

    @Test func theChainIsKnown() {
        #expect(BlockChains.knownBlockChains.contains { $0.id == PolkadotChain.default.id })
    }

    @Test func theBridgeNamesTheCoinBack() throws {
        let coin = AssetInstance(PolkadotChain.default.mainContract)
        let contract = try #require(BlockChains.contract(of: coin) as? PolkadotContract)
        #expect(contract == PolkadotChain.default.mainContract)
    }

    @Test func theBridgeNamesAnAccountOnTheChain() throws {
        let account = try AssetInstance(validating: PolkadotChain.default.id + ":" + "13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFsTB")
        let contract = try #require(BlockChains.contract(of: account) as? PolkadotContract)
        #expect(contract.address == "13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFsTB")
    }

    // MARK: The reference rows (design § 2.4)

    /// CoinGecko's `polkadot` platform lists Asset Hub's assets by their ids (USDC's recorded `1337`), a parachain's, not the relay chain's, so the table has no row for it
    @Test func coinGeckoHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinGecko]?.values.contains(PolkadotChain.default.id) == false)
        #expect(throws: AssetRegistryError.self) { try AssetRegistry.chainId(named: "polkadot", by: .coinGecko) }
        #expect(AssetImporter.admittedChain(platform: "polkadot") == nil)
    }

    /// CoinMarketCap's recorded listing names no platform for the chain, so the table has no row for it
    @Test func coinMarketCapHasNoRowForTheChain() {
        #expect(AssetRegistry.referenceChainIds[.coinMarketCap]?.values.contains(PolkadotChain.default.id) == false)
    }

    // MARK: The scanner

    @Test func theScannerIsTheChainsSidecarReadWithNoUnwrap() {
        #expect(PolkadotChain.default.scanner.userReadableName == "Substrate API Sidecar")
        #expect(PolkadotChain.default.scanner.endPoint.absoluteString == "https://polkadot-public-sidecar.parity-chains.parity.io")
    }

    /// The recorded balance of the treasury's account (`modl` and `py/trsry`), 29,475,447,871,361 planck free, at DOT's declared 10
    @Test func theRecordedBalanceIsTheCoinAtItsDecimals() throws {
        let response: SubstrateSidecar<PolkadotContract>.BalanceInfoResponse = try CoinGeckoRecorded.data("Polkadot/balance-info.json").fromJSON()
        let amount = try response.amount()
        #expect(response.tokenSymbol == "DOT")
        #expect(amount.quantity == 29_475_447_871_361)
        #expect(amount.currency == PolkadotChain.default.mainContract)
        #expect(try AssetRegistry.shared.decimals(of: AssetInstance(amount.currency)) == 10)
    }

    /// The sidecar lists no account's transactions: they throw, never an empty list
    @Test func transactionsThrow() async throws {
        let account = try PolkadotChain.default.contract(for: "13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFsTB")
        await #expect(throws: SubstrateSidecarResponseError.self) {
            try await PolkadotChain.default.scanner.getTransactions(forAccount: account)
        }
        #expect(throws: SubstrateSidecarResponseError.self) { try PolkadotChain.default.scanner.loadTransactions(from: Data()) }
    }

    @Test func aTokensBalanceIsNotRead() async throws {
        let account = try PolkadotChain.default.contract(for: "13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFsTB")
        let other = try PolkadotChain.default.contract(for: "15rRgsWxz4H5LTnNGcCFsszfXD8oeAFd8QRsR6MbQE2f6XFF")
        await #expect(throws: SubstrateSidecarResponseError.self) {
            try await PolkadotChain.default.scanner.getBalance(forToken: other, forAccount: account)
        }
    }

    // MARK: Helpers

    private static func tenToThe(_ exponent: Int) -> UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }
}
