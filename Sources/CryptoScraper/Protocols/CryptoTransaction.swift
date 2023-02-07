// CryptoTransaction.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// Describes a top-level transaction in the block chain
public protocol CryptoTransaction {
    var fromContract: CryptoContract? { get }
    var toContract: CryptoContract? { get }
    var amount: CryptoAmount { get }
    var timeStamp: Date { get }
    var transactionId: String { get }
    var gas: Int? { get }
    var gasPrice: CryptoAmount? { get }
    var gasUsed: CryptoAmount? { get }
    var successful: Bool { get }
}
