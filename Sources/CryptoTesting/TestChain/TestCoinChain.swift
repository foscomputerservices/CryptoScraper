// TestCoinChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import Foundation

public final class TestCoinChain: CryptoChain {
    // MARK: CryptoChain Protocol

    public let userReadableName = "TestChain"
    public let chainTokenInfos: Set<SimpleTokenInfo<TestCoinContract>> = []
    public let mainContract: TestCoinContract!
    public var equivalentContracts: [TestCoinContract: Set<TestCoinContract>]

    public func contract(for address: String) throws -> TestCoinContract {
        .init(address: address)
    }

    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        // N/A
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<TestCoinContract>? {
        .init(
            contractAddress: .init(address: address),
            equivalentContracts: equivalentContracts[.init(address: address)] ?? [],
            tokenName: address,
            symbol: address
        )
    }

    public let scanner: TCScan? = .init()

    static let tcContractAddress = "TestCoin"

    public static var `default`: TestCoinChain = .init()

    public init() {
        self.mainContract = .init(address: Self.tcContractAddress)
        self.equivalentContracts = [:]
    }
}
