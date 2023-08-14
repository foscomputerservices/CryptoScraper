// CryptoTransaction.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// Describes a top-level transaction in the block chain
public protocol CryptoTransaction: Codable {
    var hash: String { get }
    var fromContract: (any CryptoContract)? { get }
    var toContract: (any CryptoContract)? { get }
    var amount: CryptoAmount { get }
    var timeStamp: Date { get }
    var transactionId: String { get }
    var gas: Int? { get } // TODO: Needed??
    var gasPrice: CryptoAmount? { get }
    var gasUsed: CryptoAmount? { get }
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
    var chain: any CryptoChain {
        let contract = (fromContract ?? toContract)!
        return contract.chain as any CryptoChain
    }

    /// Calculates the final fee paid in gas for this transaction
    var gasFee: CryptoAmount? {
        guard let gasUsed, let gasPrice else { return nil }

        return .init(
            quantity: gasUsed.quantity * gasPrice.quantity,
            contract: gasUsed.contract
        )
    }
}
