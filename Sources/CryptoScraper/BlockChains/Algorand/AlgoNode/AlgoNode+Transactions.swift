// AlgoNode+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension AlgoNode {
    /// Retrieves the ``CryptoTransaction``s for the given account: its latest payments and asset transfers
    ///
    /// - Parameter account: The account from which to retrieve the transactions
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let response: TransactionsResponse = try await Self.get(
            Self.indexerEndPoint.appending(path: "accounts").appending(path: account.address)
                .appending(path: "transactions").appending(queryItems: [.init(name: "limit", value: "20")])
        )

        return response.cryptoTransactions()
    }

    /// Retrieves the ``CryptoTransaction``s of one indexer `/v2/accounts/{address}/transactions` answer
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: TransactionsResponse = try data.fromJSON()
        return response.cryptoTransactions()
    }
}

extension AlgoNode {
    /// The indexer's transactions: each a payment (`pay`), an asset transfer (`axfer`), or another kind
    struct TransactionsResponse: Decodable, Sendable {
        let transactions: [Transaction]

        struct Transaction: Decodable, Sendable {
            let id: String
            let txType: String
            let sender: String
            let fee: UInt64
            let roundTime: Int64
            let payment: Payment?
            let assetTransfer: AssetTransfer?

            struct Payment: Decodable, Sendable {
                let amount: UInt64
                let receiver: String
            }

            struct AssetTransfer: Decodable, Sendable {
                let amount: UInt64
                let assetId: UInt64
                let receiver: String

                private enum CodingKeys: String, CodingKey {
                    case amount
                    case assetId = "asset-id"
                    case receiver
                }
            }

            private enum CodingKeys: String, CodingKey {
                case id
                case txType = "tx-type"
                case sender
                case fee
                case roundTime = "round-time"
                case payment = "payment-transaction"
                case assetTransfer = "asset-transfer-transaction"
            }
        }

        /// One transaction per payment, in ALGO, and per asset transfer, in its asset's contract (its numeric id),
        /// each counted in base units with the fee in microalgos; any other kind is left out. The indexer lists
        /// confirmed transactions only, so each is successful.
        func cryptoTransactions() -> [any CryptoTransaction] {
            let coin = AlgorandChain.default.mainContract!
            return transactions.compactMap { transaction -> (any CryptoTransaction)? in
                let amount: Amount<AlgorandContract>, receiver: String
                if transaction.txType == "pay", let payment = transaction.payment {
                    amount = .init(quantity: Int128(payment.amount), currency: coin)
                    receiver = payment.receiver
                } else if transaction.txType == "axfer", let transfer = transaction.assetTransfer {
                    amount = .init(
                        quantity: Int128(transfer.amount), currency: AlgorandContract(address: String(transfer.assetId))
                    )
                    receiver = transfer.receiver
                } else {
                    return nil
                }
                return MappedTransaction(
                    hash: transaction.id,
                    fromContract: AlgorandContract(address: transaction.sender),
                    toContract: AlgorandContract(address: receiver),
                    amount: amount,
                    timeStamp: Date(timeIntervalSince1970: TimeInterval(transaction.roundTime)),
                    transactionId: transaction.id,
                    gasPrice: .init(quantity: Int128(transaction.fee), currency: coin),
                    type: transaction.txType
                )
            }
        }
    }

    private struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = AlgorandContract

        let hash: String
        let fromContract: AlgorandContract?
        let toContract: AlgorandContract?
        let amount: Amount<AlgorandContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<AlgorandContract>?
        var gasUsed: Amount<AlgorandContract>? { nil }
        var successful: Bool { true }
        var functionName: String? { nil }
        let type: String?
    }
}
