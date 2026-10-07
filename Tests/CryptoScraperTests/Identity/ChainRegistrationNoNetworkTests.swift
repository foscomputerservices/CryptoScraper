// ChainRegistrationNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoScraper
import FOSFoundation
import Foundation
import Testing

/// Design § 1.3 "Where they live": `BlockChains` learns a chain this target cannot see, an exchange chain, by
/// registration, and `contract(of:)` then answers for its contracts. A test chain on the reserved-fake `bedrock`
/// namespace stands in for an exchange chain, registered in this suite alone; a second `bedrock` chain id, never
/// registered, answers none.
@Suite struct ChainRegistrationNoNetworkTests {
    @Test func anUnregisteredChainsContractIsNone() throws {
        #expect(try BlockChains.contract(of: AssetInstance(validating: "bedrock:8:boulder")) == nil)
    }

    @Test func aRegisteredChainsContractIsNamed() throws {
        let instance = try AssetInstance(validating: RegistrationTestChain.chainId + ":pebble")
        BlockChains.register(RegistrationTestChain.default)
        let contract = try #require(BlockChains.contract(of: instance) as? RegistrationTestContract)
        #expect(contract == RegistrationTestContract(address: "pebble"))
        #expect(AssetInstance(contract) == instance)
    }

    @Test func registeringTwiceIsRegisteringOnce() throws {
        let instance = try AssetInstance(validating: RegistrationTestChain.chainId + ":gravel")
        BlockChains.register(RegistrationTestChain.default)
        BlockChains.register(RegistrationTestChain.default)
        #expect(BlockChains.contract(of: instance) as? RegistrationTestContract == RegistrationTestContract(address: "gravel"))
    }

    @Test func aChainOfThisLibraryStillAnswers() throws {
        BlockChains.register(RegistrationTestChain.default)
        #expect(try BlockChains.contract(of: AssetInstance(validating: "eip155:1:eth"))?.isChainToken == true)
    }
}

// A chain on the reserved-fake `bedrock` namespace, never one of this library's, specifying the nil scanner.
final class RegistrationTestChain: CryptoChain, Sendable {
    static let chainId = "bedrock:7"

    let id: String = RegistrationTestChain.chainId
    let userReadableName: String = "Registration test chain"
    let mainContract: RegistrationTestContract! = RegistrationTestContract(address: "bedrock")
    let scanner = NilScanner<RegistrationTestContract>()
    var chainTokenInfos: Set<SimpleTokenInfo<RegistrationTestContract>> { [] }

    static let `default` = RegistrationTestChain()

    func contract(for address: String) throws -> RegistrationTestContract { .init(address: address) }
    func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {}
    func tokenInfo(for address: String) -> SimpleTokenInfo<RegistrationTestContract>? { nil }
}

struct RegistrationTestContract: CryptoContract, Codable, Stubbable, Sendable {
    enum Units: CurrencyUnits {
        case base

        static var chainBaseUnits: Self { .base }
        static var defaultDisplayUnits: Self { .base }

        var divisorFromBase: UInt128 { 1 }
        var displayIdentifier: String { "" }
        var displayFractionDigits: Int { 0 }
    }

    typealias Chain = RegistrationTestChain

    let address: String

    init(address: String) {
        self.address = address
    }

    static func stub() -> Self { .init(address: "pebble") }
}
