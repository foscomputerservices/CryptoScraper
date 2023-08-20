// TCScan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import Foundation

public struct TCScan: CryptoScanner {
    // MARK: CryptoScanner Protocol

    public typealias Contract = TestCoinContract

    public let userReadableName = "TCScan"

    public func getBalance(forAccount account: TestCoinContract) async throws -> Amount<Contract> {
        fatalError()
    }

    public func getBalance(forToken contract: TestCoinContract, forAccount account: TestCoinContract) async throws -> Amount<Contract> {
        fatalError()
    }

    public func getTransactions(forAccount account: TestCoinContract) async throws -> [any CryptoTransaction] {
        fatalError()
    }

    public func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        fatalError()
    }
}
