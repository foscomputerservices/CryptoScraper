// CryptoTransaction.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// Describes a top-level transaction in the block chain
public protocol CryptoTransaction: Codable, Comparable {
    associatedtype Contract: CryptoContract

    var hash: String { get }
    var fromContract: Contract? { get }
    var toContract: Contract? { get }
    var amount: Amount<Contract> { get }
    var timeStamp: Date { get }
    var transactionId: String { get }
    var gas: Int? { get } // TODO: Needed??
    var gasPrice: Amount<Contract>? { get }
    var gasUsed: Amount<Contract>? { get }
    var successful: Bool { get }
    var functionName: String? { get }

    /// An arbitrary string that the chain implementation can
    /// use to differentiate different types of transactions.
    ///
    /// For example, Ethereum has normal, token and internal
    /// transactions.
    var type: String? { get }
}

public extension CryptoTransaction {
    /// Returns the ``CryptoChain`` that owns this ``CryptoContract``
    var chain: Contract.Chain {
        .default
    }

    /// Calculates the final fee paid in gas for this transaction
    var gasFee: Amount<Contract>? {
        guard let gasUsed, let gasPrice else { return nil }

        assert(gasUsed.contract == gasPrice.contract, "Expected gasUsed contract to be the same as the gasPrice contract")

        return .init(
            quantity: gasUsed.quantity * gasPrice.quantity,
            currency: gasPrice.currency
        )
    }

    // MARK: Hashable Protocol

    func hash(into hasher: inout Hasher) {
        hasher.combine(hash)
        hasher.combine(timeStamp.timeIntervalSince1970)
        hasher.combine(amount.quantity)
    }

    // MARK: Equatable Protocol

    static func == (lhs: Self, rhs: Self) -> Bool {
        // - NOTE: The way that block chains work, there can be multiple ``CryptoTransaction``s
        //   with the same ``hash`` value, so we need to compare more than just *hash*

        var result = lhs.hash == rhs.hash

        result = result && lhs.fromContract == rhs.fromContract
        result = result && lhs.toContract == rhs.toContract
        result = result && lhs.amount == rhs.amount
        result = result && lhs.transactionId == rhs.transactionId
        result = result && lhs.successful == rhs.successful

        return result
    }

    // MARK: Comparable Protocol

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.timeStamp < rhs.timeStamp
    }
}
