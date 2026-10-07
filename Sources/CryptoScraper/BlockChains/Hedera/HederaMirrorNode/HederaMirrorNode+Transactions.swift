// HederaMirrorNode+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension HederaMirrorNode {
    /// Retrieves the ``CryptoTransaction``s for the given account: its latest transactions, newest first, each the
    /// HBAR it moved for the account
    ///
    /// - Parameter account: The account from which to retrieve the transactions
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let response: TransactionsResponse = try await Self.get(
            Self.endPoint.appending(path: "transactions").appending(queryItems: [
                .init(name: "account.id", value: account.address),
                .init(name: "limit", value: "20"),
                .init(name: "order", value: "desc")
            ])
        )

        return response.cryptoTransactions(forAccount: account)
    }

    /// Retrieves the ``CryptoTransaction``s of one `/api/v1/transactions` answer: each transaction's payer and the
    /// HBAR it paid in all
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: TransactionsResponse = try data.fromJSON()
        return response.cryptoTransactions(forAccount: nil)
    }
}

extension HederaMirrorNode {
    /// `/api/v1/transactions`: each transaction with its HBAR transfers, signed tinybars per account
    struct TransactionsResponse: Decodable, Sendable {
        let transactions: [Transaction]

        struct Transaction: Decodable, Sendable {
            let transactionId: String
            let name: String
            let result: String
            let consensusTimestamp: String
            let chargedTxFee: Int64
            let transfers: [Transfer]

            struct Transfer: Decodable, Sendable {
                let account: String
                let amount: Int64
            }

            private enum CodingKeys: String, CodingKey {
                case transactionId = "transaction_id"
                case name
                case result
                case consensusTimestamp = "consensus_timestamp"
                case chargedTxFee = "charged_tx_fee"
                case transfers
            }

            /// The payer, the account before the transaction id's first `-`: `0.0.10904488-1791080103-000001216`
            var payer: String {
                String(transactionId.prefix { $0 != "-" })
            }

            /// The consensus time, `<seconds>.<nanoseconds>`, to the second
            var time: Date {
                Date(timeIntervalSince1970: TimeInterval(Int64(consensusTimestamp.prefix { $0 != "." }) ?? 0))
            }
        }

        /// One transaction per transaction: the HBAR `account` gained or lost in it (its transfers summed), from the
        /// payer to the account when it gained; with no account, the payer's own. The fee charged is the
        /// payer's, in tinybars; success is the result `SUCCESS`.
        func cryptoTransactions(forAccount account: HederaContract?) -> [any CryptoTransaction] {
            let coin = HederaChain.default.mainContract!
            return transactions.map { transaction in
                let holder = account?.address ?? transaction.payer
                let change = transaction.transfers.filter { $0.account == holder }.reduce(Int128(0)) { $0 + Int128($1.amount) }
                return MappedTransaction(
                    hash: transaction.transactionId,
                    fromContract: HederaContract(address: change > 0 ? transaction.payer : holder),
                    toContract: change > 0 ? HederaContract(address: holder) : nil,
                    amount: .init(quantity: change < 0 ? -change : change, currency: coin),
                    timeStamp: transaction.time,
                    transactionId: transaction.transactionId,
                    gasPrice: .init(quantity: Int128(transaction.chargedTxFee), currency: coin),
                    successful: transaction.result == "SUCCESS",
                    type: transaction.name
                )
            }
        }
    }

    private struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = HederaContract

        let hash: String
        let fromContract: HederaContract?
        let toContract: HederaContract?
        let amount: Amount<HederaContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<HederaContract>?
        var gasUsed: Amount<HederaContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}
