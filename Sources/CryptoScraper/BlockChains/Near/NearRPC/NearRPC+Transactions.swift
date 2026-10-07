// NearRPC+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension NearRPC {
    /// Retrieves the ``CryptoTransaction``s for the given account: the latest receipts NearBlocks lists for it, sent
    /// and received, newest first, each its deposit in NEAR
    ///
    /// - NOTE: One transaction makes several receipts, so several share a ``CryptoTransaction/hash``; each has its own
    ///   ``CryptoTransaction/transactionId``, the receipt's id.
    ///
    /// - Parameter account: The account from which to retrieve the transactions
    /// - Throws: ``NearRPCResponseError/requestFailed(_:)`` when a receipt states no whole deposit, burnt fee or time
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        var url = Self.indexer.appending(path: "v1").appending(path: "account").appending(path: account.address)
            .appending(path: "txns")
        url.append(queryItems: [.init(name: "per_page", value: "25")])
        let response: TransactionsResponse = try await DataFetch<URLSession>.default.send(
            to: url, httpMethod: "GET", headers: nil, locale: nil
        )

        return try response.cryptoTransactions()
    }

    /// Retrieves the ``CryptoTransaction``s of one NearBlocks `/v1/account/{id}/txns` answer
    /// - Throws: ``NearRPCResponseError/requestFailed(_:)`` when a receipt states no whole deposit, burnt fee or time
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: TransactionsResponse = try data.fromJSON()
        return try response.cryptoTransactions()
    }
}

extension NearRPC {
    /// NearBlocks' `/v1/account/{id}/txns`: `{ "cursor", "txns": [<receipt>] }`, each receipt's amounts JSON numbers
    struct TransactionsResponse: Decodable, Sendable {
        let txns: [Receipt]

        struct Receipt: Decodable, Sendable {
            let receiptId: String
            let predecessorAccountId: String
            let receiverAccountId: String
            let transactionHash: String
            let blockTimestamp: String
            let receiptOutcome: Outcome
            let actions: [Action]
            let actionsAgg: Aggregate

            struct Outcome: Decodable, Sendable {
                let tokensBurnt: Decimal
                let status: Bool?

                private enum CodingKeys: String, CodingKey {
                    case tokensBurnt = "tokens_burnt"
                    case status
                }
            }

            struct Action: Decodable, Sendable {
                let action: String
            }

            struct Aggregate: Decodable, Sendable {
                let deposit: Decimal
            }

            private enum CodingKeys: String, CodingKey {
                case receiptId = "receipt_id"
                case predecessorAccountId = "predecessor_account_id"
                case receiverAccountId = "receiver_account_id"
                case transactionHash = "transaction_hash"
                case blockTimestamp = "block_timestamp"
                case receiptOutcome = "receipt_outcome"
                case actions
                case actionsAgg = "actions_agg"
            }
        }

        /// One transaction per receipt: its deposit from its predecessor to its receiver, its fee the tokens its
        /// outcome burnt, its success the outcome's status, its time the transaction's block's (nanoseconds), its type
        /// its first action's
        func cryptoTransactions() throws -> [any CryptoTransaction] {
            let coin = NearChain.default.mainContract!
            return try txns.map { receipt in
                guard
                    let deposit = NearRPC.yocto(receipt.actionsAgg.deposit),
                    let burnt = NearRPC.yocto(receipt.receiptOutcome.tokensBurnt),
                    let nanoseconds = Int128(receipt.blockTimestamp)
                else {
                    throw NearRPCResponseError.requestFailed("receipt \(receipt.receiptId) states no whole amounts")
                }
                return MappedTransaction(
                    hash: receipt.transactionHash,
                    fromContract: NearContract(address: receipt.predecessorAccountId),
                    toContract: NearContract(address: receipt.receiverAccountId),
                    amount: .init(quantity: deposit, currency: coin),
                    timeStamp: Date(timeIntervalSince1970: TimeInterval(nanoseconds / 1_000_000) / 1000),
                    transactionId: receipt.receiptId,
                    gasPrice: .init(quantity: burnt, currency: coin),
                    successful: receipt.receiptOutcome.status ?? false,
                    type: receipt.actions.first?.action
                )
            }
        }
    }
}
