// TestCoinTransaction.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import Foundation

public struct TestCoinTransaction<FC, TC>: CryptoTransaction where FC: CryptoContract, TC: CryptoContract {
    public let hash: String
    public var fromContract: (any CryptoContract)? { _fromContract }
    public var toContract: (any CryptoContract)? { _toContract }
    public let amount: CryptoAmount
    public let timeStamp: Date
    public let transactionId: String
    public let gas: Int?
    public let gasPrice: CryptoAmount?
    public let gasUsed: CryptoAmount?
    public let successful: Bool
    public let functionName: String?
    public var type: String? { nil }

    private let _fromContract: FC?
    private let _toContract: TC?

    public init(hash: String, fromContract: FC?, toContract: TC?, amount: CryptoAmount, timeStamp: Date, transactionId: String, gas: Int? = nil, gasPrice: CryptoAmount? = nil, gasUsed: CryptoAmount? = nil, successful: Bool = true, functionName: String? = nil) {
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

public extension TestCoinTransaction where FC == TestCoinContract {
    init(hash: String, toContract: TC?, amount: CryptoAmount, timeStamp: Date, transactionId: String, gas: Int? = nil, gasPrice: CryptoAmount? = nil, gasUsed: CryptoAmount? = nil, successful: Bool = true, functionName: String? = nil) {
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

public extension TestCoinTransaction where TC == TestCoinContract {
    init(hash: String, fromContract: FC?, amount: CryptoAmount, timeStamp: Date, transactionId: String, gas: Int? = nil, gasPrice: CryptoAmount? = nil, gasUsed: CryptoAmount? = nil, successful: Bool = true, functionName: String? = nil) {
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
