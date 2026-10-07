// VeChainThor+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension VeChainThor {
    /// Retrieves the ``CryptoTransaction``s for the given account: its latest VET transfers, sent and received,
    /// newest first
    ///
    /// - Parameter account: The account from which to retrieve the transactions
    /// - Throws: ``VeChainThorResponseError/requestFailed(_:)`` when a transfer's amount is not a count of wei in hex
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let body = try JSONSerialization.data(withJSONObject: [
            "options": ["offset": 0, "limit": 20],
            "criteriaSet": [["sender": account.address], ["recipient": account.address]],
            "order": "desc"
        ] as [String: Any])
        let response: [TransferLog] = try await DataFetch<URLSession>.default.send(
            data: body, to: Self.endPoint.appending(path: "logs").appending(path: "transfer"), httpMethod: "POST",
            headers: [(field: "Content-Type", value: "application/json")], locale: nil
        )

        return try TransferLog.cryptoTransactions(response)
    }

    /// Retrieves the ``CryptoTransaction``s of one `/logs/transfer` answer
    /// - Throws: ``VeChainThorResponseError/requestFailed(_:)`` when a transfer's amount is not a count of wei in hex
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: [TransferLog] = try data.fromJSON()
        return try TransferLog.cryptoTransactions(response)
    }
}

extension VeChainThor {
    /// One `/logs/transfer` row: a VET transfer, `{ "sender": …, "recipient": …, "amount": "0x<wei>", "meta": … }`
    struct TransferLog: Decodable, Sendable {
        let sender: String
        let recipient: String
        let amount: String
        let meta: Meta

        struct Meta: Decodable, Sendable {
            let txID: String
            let blockTimestamp: Int64
        }

        /// One transaction per transfer: its VET from its sender to its recipient. The log holds executed transfers
        /// only, so each is successful; it carries no fee.
        static func cryptoTransactions(_ logs: [TransferLog]) throws -> [any CryptoTransaction] {
            let coin = VeChainChain.default.mainContract!
            return try logs.map { log in
                guard let quantity = VeChainThor.quantity(hex: log.amount) else {
                    throw VeChainThorResponseError.requestFailed("\(log.amount) is not a count of wei")
                }
                return MappedTransaction(
                    hash: log.meta.txID,
                    fromContract: VeChainContract(address: log.sender),
                    toContract: VeChainContract(address: log.recipient),
                    amount: .init(quantity: quantity, currency: coin),
                    timeStamp: Date(timeIntervalSince1970: TimeInterval(log.meta.blockTimestamp)),
                    transactionId: log.meta.txID,
                    gasPrice: nil,
                    successful: true,
                    type: "transfer"
                )
            }
        }
    }
}
