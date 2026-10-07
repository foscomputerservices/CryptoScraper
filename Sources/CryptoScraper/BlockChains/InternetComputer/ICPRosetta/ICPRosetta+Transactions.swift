// ICPRosetta+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension ICPRosetta {
    /// Retrieves the ``CryptoTransaction``s for the given account identifier: its latest transactions, newest first,
    /// each the ICP the account gained or lost in it
    ///
    /// - Parameter account: The account identifier from which to retrieve the transactions
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let response: SearchResponse = try await Self.post(
            "search/transactions", ["account_identifier": ["address": account.address], "limit": 25]
        )

        return try response.cryptoTransactions(forAccount: account)
    }

    /// A Rosetta search answer does not name the account it was asked about, so it is read only for an account
    ///
    /// - Throws: ``ICPRosettaResponseError/requestFailed(_:)``, always: use ``loadTransactions(from:forAccount:)``
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        throw ICPRosettaResponseError.requestFailed("a search answer is read for an account; none was given")
    }

    /// Retrieves the ``CryptoTransaction``s of one `/search/transactions` answer for `account`
    func loadTransactions(from data: Data, forAccount account: Contract) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: SearchResponse = try data.fromJSON()
        return try response.cryptoTransactions(forAccount: account)
    }
}

extension ICPRosetta {
    /// `/search/transactions`: `{ "transactions": [{ "block_identifier", "transaction": { "transaction_identifier",
    /// "operations": [{ "type", "status", "account", "amount" }], "metadata": { "timestamp" } } }], "total_count" }`
    struct SearchResponse: Decodable, Sendable {
        let transactions: [Row]

        struct Row: Decodable, Sendable {
            let transaction: Transaction

            struct Transaction: Decodable, Sendable {
                let transactionIdentifier: Identifier
                let operations: [Operation]
                let metadata: Metadata

                struct Identifier: Decodable, Sendable {
                    let hash: String
                }

                struct Operation: Decodable, Sendable {
                    let type: String
                    let status: String
                    let account: Account
                    let amount: RosettaAmount

                    struct Account: Decodable, Sendable {
                        let address: String
                    }
                }

                struct Metadata: Decodable, Sendable {
                    let timestamp: Int64
                }

                private enum CodingKeys: String, CodingKey {
                    case transactionIdentifier = "transaction_identifier"
                    case operations
                    case metadata
                }
            }
        }

        /// One transaction per row: the ICP `account` gained or lost (its `TRANSACTION` operations summed), from the
        /// other party's account to it when it gained or nothing changed, from it to the other party when it lost. The
        /// fee is the `FEE` operation's, in e8s, paid by its account; success is every operation `COMPLETED`; the time
        /// is the metadata's, in nanoseconds.
        func cryptoTransactions(forAccount account: InternetComputerContract) throws -> [any CryptoTransaction] {
            let coin = InternetComputerChain.default.mainContract!
            return try transactions.map { row in
                let operations = row.transaction.operations
                let transfers = operations.filter { $0.type == "TRANSACTION" }
                let change = try transfers.filter { $0.account.address == account.address }
                    .reduce(Int128(0)) { total, operation in try total + operation.amount.e8s() }
                let other = transfers.first { $0.account.address != account.address }
                    .map { InternetComputerContract(address: $0.account.address) }
                let fee = try operations.first { $0.type == "FEE" }.map { try -$0.amount.e8s() }
                let received = change >= 0
                return MappedTransaction(
                    hash: row.transaction.transactionIdentifier.hash,
                    fromContract: received ? other : account,
                    toContract: received ? account : other,
                    amount: .init(quantity: received ? change : -change, currency: coin),
                    timeStamp: Date(
                        timeIntervalSince1970: TimeInterval(row.transaction.metadata.timestamp / 1_000_000) / 1000
                    ),
                    transactionId: row.transaction.transactionIdentifier.hash,
                    gasPrice: fee.map { .init(quantity: $0, currency: coin) },
                    successful: operations.allSatisfy { $0.status == "COMPLETED" },
                    type: transfers.isEmpty ? operations.first?.type : "TRANSACTION"
                )
            }
        }
    }
}
