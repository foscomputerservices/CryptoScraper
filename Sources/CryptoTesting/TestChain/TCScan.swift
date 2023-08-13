// TCScan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import Foundation

public struct TCScan: CryptoScanner {
    // MARK: CryptoScanner Protocol

    public let userReadableName = "TCScan"

    public func getBalance(forAccount account: TestCoinContract) async throws -> CryptoAmount {
        fatalError()
    }

    public func getBalance(forToken contract: TestCoinContract, forAccount account: TestCoinContract) async throws -> CryptoAmount {
        fatalError()
    }

    public func getTransactions(forAccount account: TestCoinContract) async throws -> [CryptoTransaction] {
        fatalError()
    }

    public func loadTransactions(from data: Data) throws -> [CryptoTransaction] {
        fatalError()
    }
}
