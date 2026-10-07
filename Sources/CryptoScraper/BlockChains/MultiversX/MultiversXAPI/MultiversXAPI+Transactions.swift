// MultiversXAPI+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension MultiversXAPI {
    /// Retrieves the ``CryptoTransaction``s for the given account: its latest transactions, newest first, each the
    /// EGLD it moved
    ///
    /// - Parameter account: The account from which to retrieve the transactions
    /// - Throws: ``MultiversXAPIResponseError/requestFailed(_:)`` when a row's value is not a count of atomic units
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let response: [Transaction] = try await Self.endPoint
            .appending(path: "accounts").appending(path: account.address).appending(path: "transactions")
            .appending(queryItems: [.init(name: "size", value: "20")])
            .fetch()

        return try Transaction.cryptoTransactions(response)
    }

    /// Retrieves the ``CryptoTransaction``s of one `/accounts/{address}/transactions` answer
    /// - Throws: ``MultiversXAPIResponseError/requestFailed(_:)`` when a row's value is not a count of atomic units
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: [Transaction] = try data.fromJSON()
        return try Transaction.cryptoTransactions(response)
    }
}

extension MultiversXAPI {
    /// One `/accounts/{address}/transactions` row: its sender, receiver, value and fee in atomic units, its status
    struct Transaction: Decodable, Sendable {
        let txHash: String
        let sender: String
        let receiver: String
        let value: String
        let fee: String?
        let status: String
        let timestamp: Int64
        let function: String?

        /// One transaction per row: its value from its sender to its receiver; the fee is the sender's; success is
        /// the status `success`
        static func cryptoTransactions(_ rows: [Transaction]) throws -> [any CryptoTransaction] {
            let coin = MultiversXChain.default.mainContract!
            return try rows.map { row in
                guard let quantity = Int128(row.value) else {
                    throw MultiversXAPIResponseError.requestFailed("value \(row.value) is not a count of atomic units")
                }
                return MappedTransaction(
                    hash: row.txHash,
                    fromContract: MultiversXContract(address: row.sender),
                    toContract: MultiversXContract(address: row.receiver),
                    amount: .init(quantity: quantity, currency: coin),
                    timeStamp: Date(timeIntervalSince1970: TimeInterval(row.timestamp)),
                    transactionId: row.txHash,
                    gasPrice: row.fee.flatMap(Int128.init).map { .init(quantity: $0, currency: coin) },
                    successful: row.status == "success",
                    type: row.function
                )
            }
        }
    }
}
