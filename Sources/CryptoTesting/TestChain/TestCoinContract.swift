// TestCoinContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import Foundation

public struct TestCoinContract: CryptoContract {
    // MARK: CryptoContract Protocol

    public let address: String
    public var chain: TestCoinChain { TestCoinChain.default }
    public var isChainToken: Bool {
        address == TestCoinChain.tcContractAddress
    }

    public init(address: String) {
        self.address = address.lowercased()
    }
}
