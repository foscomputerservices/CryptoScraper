// ZeroAmountScanner.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct ZeroAmountScanner: CryptoScanner {
    public var userReadableName: String { "Zero Amount Scanner" }

    public func getBalance(forAccount account: ZeroAmountContract) async throws -> CryptoAmount {
        .zero
    }

    public func getBalance(forToken contract: ZeroAmountContract, forAccount account: ZeroAmountContract) async throws -> CryptoAmount {
        .zero
    }

    public func getTransactions(forAccount account: ZeroAmountContract) async throws -> [CryptoTransaction] {
        []
    }

    public func loadTransactions(from data: Data) throws -> [CryptoTransaction] {
        []
    }
}
