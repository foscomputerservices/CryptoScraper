// Filfox+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension Filfox {
    /// Retrieves the ``CryptoTransaction``s for the given address: its latest messages, newest first, each the FIL
    /// it moved
    ///
    /// - Parameter account: The address from which to retrieve the transactions
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let response: MessagesResponse = try await Self.endPoint
            .appending(path: "address").appending(path: account.address).appending(path: "messages")
            .appending(queryItems: [.init(name: "pageSize", value: "20"), .init(name: "page", value: "0")])
            .fetch()

        return try response.cryptoTransactions()
    }

    /// Retrieves the ``CryptoTransaction``s of one `/address/{address}/messages` answer
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: MessagesResponse = try data.fromJSON()
        return try response.cryptoTransactions()
    }
}

extension Filfox {
    /// `/address/{address}/messages`: each message, its sender, its receiver, its value in attoFIL and its receipt
    struct MessagesResponse: Decodable, Sendable {
        let messages: [Message]

        struct Message: Decodable, Sendable {
            let cid: String
            let timestamp: Int64
            let from: String
            let to: String
            let value: String
            let method: String
            let receipt: Receipt?

            struct Receipt: Decodable, Sendable {
                let exitCode: Int
            }
        }

        /// One transaction per message: its value from its sender to its receiver; success is an exit code of 0. The
        /// list carries no fee.
        func cryptoTransactions() throws -> [any CryptoTransaction] {
            let coin = FilecoinChain.default.mainContract!
            return try messages.map { message in
                guard let quantity = Int128(message.value) else {
                    throw FilfoxResponseError.requestFailed("value \(message.value) is not a count of attoFIL")
                }
                return MappedTransaction(
                    hash: message.cid,
                    fromContract: FilecoinContract(address: message.from),
                    toContract: FilecoinContract(address: message.to),
                    amount: .init(quantity: quantity, currency: coin),
                    timeStamp: Date(timeIntervalSince1970: TimeInterval(message.timestamp)),
                    transactionId: message.cid,
                    gasPrice: nil,
                    successful: message.receipt?.exitCode == 0,
                    type: message.method
                )
            }
        }
    }
}
