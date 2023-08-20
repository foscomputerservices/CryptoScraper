// TestCoinTransaction.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import Foundation

public struct TestCoinTransaction: CryptoTransaction {
    public typealias Chain = TestCoinChain

    public let hash: String
    public var fromContract: Chain.Contract? { _fromContract }
    public var toContract: Chain.Contract? { _toContract }
    public let amount: Amount<Chain.Contract>
    public let timeStamp: Date
    public let transactionId: String
    public let gas: Int?
    public let gasPrice: Amount<Chain.Contract>?
    public let gasUsed: Amount<Chain.Contract>?
    public let successful: Bool
    public let functionName: String?
    public var type: String? { nil }

    private let _fromContract: Chain.Contract?
    private let _toContract: Chain.Contract?

    public init(hash: String, fromContract: Chain.Contract?, toContract: Chain.Contract?, amount: Amount<Chain.Contract>, timeStamp: Date, transactionId: String, gas: Int? = nil, gasPrice: Amount<Chain.Contract>? = nil, gasUsed: Amount<Chain.Contract>? = nil, successful: Bool = true, functionName: String? = nil) {
        self.hash = hash
        self._fromContract = fromContract
        self._toContract = toContract
        self.amount = amount
        self.timeStamp = timeStamp
        self.transactionId = transactionId
        self.gas = gas
        self.gasPrice = gasPrice
        self.gasUsed = gasUsed
        self.successful = successful
        self.functionName = functionName
    }
}

public extension TestCoinTransaction {
    init(hash: String, toContract: Chain.Contract?, amount: Amount<Chain.Contract>, timeStamp: Date, transactionId: String, gas: Int? = nil, gasPrice: Amount<Chain.Contract>? = nil, gasUsed: Amount<Chain.Contract>? = nil, successful: Bool = true, functionName: String? = nil) {
        self.hash = hash
        self._fromContract = nil
        self._toContract = toContract
        self.amount = amount
        self.timeStamp = timeStamp
        self.transactionId = transactionId
        self.gas = gas
        self.gasPrice = gasPrice
        self.gasUsed = gasUsed
        self.successful = successful
        self.functionName = functionName
    }
}

public extension TestCoinTransaction {
    init(hash: String, fromContract: Chain.Contract?, amount: Amount<Chain.Contract>, timeStamp: Date, transactionId: String, gas: Int? = nil, gasPrice: Amount<Chain.Contract>? = nil, gasUsed: Amount<Chain.Contract>? = nil, successful: Bool = true, functionName: String? = nil) {
        self.hash = hash
        self._fromContract = fromContract
        self._toContract = nil
        self.amount = amount
        self.timeStamp = timeStamp
        self.transactionId = transactionId
        self.gas = gas
        self.gasPrice = gasPrice
        self.gasUsed = gasUsed
        self.successful = successful
        self.functionName = functionName
    }
}
