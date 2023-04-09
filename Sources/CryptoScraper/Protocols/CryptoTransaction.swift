// CryptoTransaction.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// Describes a top-level transaction in the block chain
public protocol CryptoTransaction: Codable {
    var fromContract: (any CryptoContract)? { get }
    var toContract: (any CryptoContract)? { get }
    var amount: CryptoAmount { get }
    var timeStamp: Date { get }
    var transactionId: String { get }
    var gas: Int? { get }
    var gasPrice: CryptoAmount? { get }
    var gasUsed: CryptoAmount? { get }
    var successful: Bool { get }
}
