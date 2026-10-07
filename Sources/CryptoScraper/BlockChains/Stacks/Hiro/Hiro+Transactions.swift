// Hiro+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension Hiro {
    /// Retrieves the ``CryptoTransaction``s for the given principal: its latest transactions, newest first, each
    /// the STX it transferred
    ///
    /// - Parameter account: The principal from which to retrieve the transactions
    /// - Throws: ``HiroResponseError/requestFailed(_:)`` when a transaction's amount or fee is not a count of microSTX
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let response: TransactionsResponse = try await Self.endPoint
            .appending(path: "address").appending(path: account.address).appending(path: "transactions")
            .appending(queryItems: [.init(name: "limit", value: "20")])
            .fetch()

        return try response.cryptoTransactions()
    }

    /// Retrieves the ``CryptoTransaction``s of one `/address/{principal}/transactions` answer
    /// - Throws: ``HiroResponseError/requestFailed(_:)`` when a transaction's amount or fee is not a count of microSTX
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: TransactionsResponse = try data.fromJSON()
        return try response.cryptoTransactions()
    }
}

extension Hiro {
    /// `/address/{principal}/transactions`: each transaction, its sender, its fee in microSTX, its status, and for a
    /// token transfer its recipient and amount
    struct TransactionsResponse: Decodable, Sendable {
        let results: [Transaction]

        struct Transaction: Decodable, Sendable {
            let txId: String
            let txType: String
            let txStatus: String
            let senderAddress: String
            let feeRate: String
            let burnBlockTime: Int64
            let tokenTransfer: TokenTransfer?

            struct TokenTransfer: Decodable, Sendable {
                let recipientAddress: String
                let amount: String

                private enum CodingKeys: String, CodingKey {
                    case recipientAddress = "recipient_address"
                    case amount
                }
            }

            private enum CodingKeys: String, CodingKey {
                case txId = "tx_id"
                case txType = "tx_type"
                case txStatus = "tx_status"
                case senderAddress = "sender_address"
                case feeRate = "fee_rate"
                case burnBlockTime = "burn_block_time"
                case tokenTransfer = "token_transfer"
            }
        }

        /// One transaction per transaction: an STX transfer's amount from its sender to its recipient, nothing for any
        /// other kind; the fee is the sender's, in microSTX; success is the status `success`
        func cryptoTransactions() throws -> [any CryptoTransaction] {
            let coin = StacksChain.default.mainContract!
            return try results.map { transaction in
                let amount = transaction.tokenTransfer?.amount ?? "0"
                guard let quantity = Int128(amount), let fee = Int128(transaction.feeRate) else {
                    throw HiroResponseError.requestFailed("amount \(amount) or fee \(transaction.feeRate) is not a count of microSTX")
                }
                return MappedTransaction(
                    hash: transaction.txId,
                    fromContract: StacksContract(address: transaction.senderAddress),
                    toContract: transaction.tokenTransfer.map { StacksContract(address: $0.recipientAddress) },
                    amount: .init(quantity: quantity, currency: coin),
                    timeStamp: Date(timeIntervalSince1970: TimeInterval(transaction.burnBlockTime)),
                    transactionId: transaction.txId,
                    gasPrice: .init(quantity: fee, currency: coin),
                    successful: transaction.txStatus == "success",
                    type: transaction.txType
                )
            }
        }
    }
}
