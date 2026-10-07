// ArweaveGateway+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension ArweaveGateway {
    /// Retrieves the ``CryptoTransaction``s for the given wallet: the latest transactions it sent and received, each
    /// the AR it moved
    ///
    /// - Parameter account: The wallet from which to retrieve the transactions
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let fields = "edges { node { id owner { address } recipient quantity { winston } fee { winston } block { timestamp } } }"
        let query = """
            query($wallet: [String!]) { sent: transactions(owners: $wallet, first: 20) { \(fields) } \
            received: transactions(recipients: $wallet, first: 20) { \(fields) } }
            """
        let body = try JSONSerialization.data(withJSONObject: [
            "query": query, "variables": ["wallet": [account.address]]
        ] as [String: Any])
        let response: GraphQLResponse = try await DataFetch<URLSession>.default.send(
            data: body, to: Self.endPoint.appending(path: "graphql"), httpMethod: "POST",
            headers: [(field: "Content-Type", value: "application/json")], locale: nil
        )

        return try response.cryptoTransactions()
    }

    /// Retrieves the ``CryptoTransaction``s of one GraphQL answer of the gateway's `transactions`
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: GraphQLResponse = try data.fromJSON()
        return try response.cryptoTransactions()
    }
}

extension ArweaveGateway {
    /// The gateway's GraphQL answer: `{ "data": { <field>: { "edges": [{ "node": <transaction> }] }, … } }`, each
    /// field one `transactions` query, or `{ "errors": [{ "message": … }] }`
    struct GraphQLResponse: Decodable, Sendable {
        let data: [String: Connection]?
        let errors: [Failure]?

        struct Failure: Decodable, Sendable {
            let message: String
        }

        struct Connection: Decodable, Sendable {
            let edges: [Edge]

            struct Edge: Decodable, Sendable {
                let node: Node
            }
        }

        struct Node: Decodable, Sendable {
            let id: String
            let owner: Owner
            let recipient: String
            let quantity: Winston
            let fee: Winston
            let block: Block?

            struct Owner: Decodable, Sendable {
                let address: String
            }

            struct Winston: Decodable, Sendable {
                let winston: String
            }

            struct Block: Decodable, Sendable {
                let timestamp: Int64
            }
        }

        /// One transaction per transaction, each once, newest first: its AR from its owner to its recipient (none for
        /// a data transaction); the fee is the owner's, in winston. A transaction not yet in a block is pending, so not
        /// successful.
        func cryptoTransactions() throws -> [any CryptoTransaction] {
            if let errors, !errors.isEmpty {
                throw ArweaveGatewayResponseError.requestFailed(errors.map(\.message).joined(separator: "; "))
            }
            let coin = ArweaveChain.default.mainContract!
            var seen: Set<String> = []
            let nodes = (data ?? [:]).keys.sorted().flatMap { data![$0]!.edges.map(\.node) }
                .filter { seen.insert($0.id).inserted }
                .sorted { ($0.block?.timestamp ?? .max) > ($1.block?.timestamp ?? .max) }
            return try nodes.map { node in
                guard let quantity = Int128(node.quantity.winston), let fee = Int128(node.fee.winston) else {
                    throw ArweaveGatewayResponseError.requestFailed("\(node.quantity.winston) is not a count of winston")
                }
                return MappedTransaction(
                    hash: node.id,
                    fromContract: ArweaveContract(address: node.owner.address),
                    toContract: node.recipient.isEmpty ? nil : ArweaveContract(address: node.recipient),
                    amount: .init(quantity: quantity, currency: coin),
                    timeStamp: Date(timeIntervalSince1970: TimeInterval(node.block?.timestamp ?? 0)),
                    transactionId: node.id,
                    gasPrice: .init(quantity: fee, currency: coin),
                    successful: node.block != nil,
                    type: nil
                )
            }
        }
    }
}
