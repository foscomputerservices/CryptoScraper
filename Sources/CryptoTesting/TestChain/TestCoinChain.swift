// TestCoinChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import Foundation
import Synchronization

public final class TestCoinChain: CryptoChain, Sendable {
    // MARK: CryptoChain Protocol

    public let userReadableName = "TestChain"
    public let chainTokenInfos: Set<SimpleTokenInfo<TestCoinContract>> = []
    public let mainContract: TestCoinContract!
    // Settable by a test after the singleton exists and read from any domain, so it is held behind a `Mutex`.
    private let _equivalentContracts = Mutex<[TestCoinContract: Set<TestCoinContract>]>([:])
    public var equivalentContracts: [TestCoinContract: Set<TestCoinContract>] {
        get { _equivalentContracts.withLock { $0 } }
        set { _equivalentContracts.withLock { $0 = newValue } }
    }

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

    public let scanner: TCScan = .init()

    static let tcContractAddress = "TestCoin"

    public static let `default`: TestCoinChain = .init()

    public init() {
        self.mainContract = .init(address: Self.tcContractAddress)
    }
}
