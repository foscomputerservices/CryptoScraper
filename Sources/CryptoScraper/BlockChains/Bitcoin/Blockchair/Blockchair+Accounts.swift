// Blockchair+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension Blockchair {
    /// Returns the balance of the given address, counted in the chain's base unit
    ///
    /// - Parameter account: The address to query the balance for
    ///
    /// - Throws: ``BlockchairResponseError/requestFailed(_:)`` in Blockchair's words when it refuses
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        try await dashboard(of: account).amount()
    }

    /// Returns the coin's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``BlockchairResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw BlockchairResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }

    /// Retrieves the ``CryptoTransaction``s for the given address: its latest 20, newest first, each the coin its
    /// balance changed by
    ///
    /// - Parameter account: The address from which to retrieve the transactions
    ///
    /// - Throws: ``BlockchairResponseError/requestFailed(_:)`` in Blockchair's words when it refuses, or for a time
    ///   that is not Blockchair's UTC time
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        try await dashboard(of: account).cryptoTransactions()
    }

    /// Retrieves the ``CryptoTransaction``s of one address dashboard
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: DashboardResponse = try data.fromJSON()
        return try response.cryptoTransactions()
    }
}

extension Blockchair {
    /// The address's dashboard, its transactions with their details, the latest 20
    func dashboard(of account: Contract) async throws -> DashboardResponse {
        try await Self.endPoint
            .appending(path: slug).appending(path: "dashboards").appending(path: "address")
            .appending(path: apiAddress(account))
            .appending(queryItems: [
                .init(name: "transaction_details", value: "true"),
                .init(name: "limit", value: "20")
            ])
            .fetch()
    }

    /// `/<slug>/dashboards/address/<address>?transaction_details=true`: `{ "data": { "<address>": { "address":
    /// { "balance": <base units>, … }, "transactions": [ { "block_id", "hash", "time", "balance_change" } ], … } },
    /// "context": { "code", "error"?, … } }`; `data` is `null` when Blockchair refuses, its words in `context.error`
    struct DashboardResponse: Decodable, Sendable {
        let data: [String: Dashboard]?
        let context: Context

        struct Context: Decodable, Sendable {
            let code: Int
            let error: String?
        }

        struct Dashboard: Decodable, Sendable {
            let address: Address
            let transactions: [Transaction]

            struct Address: Decodable, Sendable {
                let balance: Int64
            }

            struct Transaction: Decodable, Sendable {
                let blockId: Int64
                let hash: String
                let time: String
                let balanceChange: Int64

                private enum CodingKeys: String, CodingKey {
                    case blockId = "block_id"
                    case hash
                    case time
                    case balanceChange = "balance_change"
                }
            }
        }

        /// The one address the dashboard is of, as Blockchair writes it, and its dashboard
        ///
        /// - Throws: ``BlockchairResponseError/requestFailed(_:)`` in Blockchair's words when it refused
        func dashboard() throws -> (address: String, dashboard: Dashboard) {
            guard let (address, dashboard) = data?.first, data?.count == 1 else {
                throw BlockchairResponseError.requestFailed(
                    context.error ?? "Blockchair answered code \(context.code) with no address"
                )
            }
            return (address, dashboard)
        }

        /// The balance in the chain's main contract, counted in its base unit
        func amount() throws -> Amount<Contract> {
            try .init(
                quantity: Int128(dashboard().dashboard.address.balance),
                currency: Contract.Chain.default.mainContract
            )
        }

        /// One transaction per transaction: the size of the address's balance change in the chain's coin, received
        /// when it grew (the address its recipient), sent when it shrank (the address its sender); Blockchair states
        /// no fee here, and each listed transaction is accepted, so successful
        func cryptoTransactions() throws -> [any CryptoTransaction] {
            let (address, dashboard) = try dashboard()
            let chain = Contract.Chain.default
            let account = try chain.contract(for: address)
            return try dashboard.transactions.map { transaction in
                guard let timeStamp = Self.date(transaction.time) else {
                    throw BlockchairResponseError.requestFailed("time \(transaction.time) is not Blockchair's UTC time")
                }
                let received = transaction.balanceChange >= 0
                return MappedTransaction(
                    hash: transaction.hash,
                    fromContract: received ? nil : account,
                    toContract: received ? account : nil,
                    amount: .init(quantity: Int128(transaction.balanceChange.magnitude), currency: chain.mainContract),
                    timeStamp: timeStamp,
                    transactionId: transaction.hash,
                    successful: true
                )
            }
        }

        /// Blockchair's time, `2020-01-02 03:04:05`, in UTC; `nil` for any other text
        static func date(_ text: String) -> Date? {
            guard text.count == 19, text.dropFirst(10).first == " " else {
                return nil
            }
            return try? Date(text.replacingOccurrences(of: " ", with: "T") + "Z", strategy: .iso8601)
        }
    }
}
