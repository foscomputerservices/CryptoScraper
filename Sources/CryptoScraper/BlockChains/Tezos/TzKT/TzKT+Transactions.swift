// TzKT+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension TzKT {
    /// Retrieves the ``CryptoTransaction``s for the given account: its latest transaction operations
    ///
    /// - Parameter account: The account from which to retrieve the transactions
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let response: [OperationResponse] = try await Self.endPoint.appending(path: "accounts")
            .appending(path: account.address)
            .appending(path: "operations")
            .appending(queryItems: [.init(name: "type", value: "transaction"), .init(name: "limit", value: "20")])
            .fetch()

        return OperationResponse.cryptoTransactions(response)
    }

    /// Retrieves the ``CryptoTransaction``s of one `/v1/accounts/{address}/operations` answer, as TzKT sends it
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: [OperationResponse] = try data.fromJSON()
        return OperationResponse.cryptoTransactions(response)
    }
}

extension TzKT {
    /// One operation of `/v1/accounts/{address}/operations`
    struct OperationResponse: Decodable, Sendable {
        let type: String
        let hash: String
        let timestamp: Date
        let sender: Party?
        let target: Party?
        let amount: Int64?
        let bakerFee: Int64?
        let status: String?

        struct Party: Decodable, Sendable {
            let address: String
        }

        private enum CodingKeys: String, CodingKey {
            case type, hash, timestamp, sender, target, amount, bakerFee, status
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try container.decode(String.self, forKey: .type)
            self.hash = try container.decode(String.self, forKey: .hash)
            let time = try container.decode(String.self, forKey: .timestamp)
            guard let date = ISO8601DateFormatter().date(from: time) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .timestamp, in: container, debugDescription: "Not an ISO 8601 time: \(time)"
                )
            }
            self.timestamp = date
            self.sender = try container.decodeIfPresent(Party.self, forKey: .sender)
            self.target = try container.decodeIfPresent(Party.self, forKey: .target)
            self.amount = try container.decodeIfPresent(Int64.self, forKey: .amount)
            self.bakerFee = try container.decodeIfPresent(Int64.self, forKey: .bakerFee)
            self.status = try container.decodeIfPresent(String.self, forKey: .status)
        }

        /// One transaction per transaction operation: the XTZ moved in mutez, the baker's fee, success when its
        /// status is `applied` (TzKT's word; `failed`, `backtracked` and `skipped` are not)
        static func cryptoTransactions(_ operations: [OperationResponse]) -> [any CryptoTransaction] {
            let coin = TezosChain.default.mainContract!
            return operations.filter { $0.type == "transaction" }.map { operation in
                MappedTransaction(
                    hash: operation.hash,
                    fromContract: operation.sender.map { TezosContract(address: $0.address) },
                    toContract: operation.target.map { TezosContract(address: $0.address) },
                    amount: .init(quantity: Int128(operation.amount ?? 0), currency: coin),
                    timeStamp: operation.timestamp,
                    transactionId: operation.hash,
                    gasPrice: operation.bakerFee.map { .init(quantity: Int128($0), currency: coin) },
                    successful: operation.status == "applied",
                    type: operation.type
                )
            }
        }
    }

    private struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = TezosContract

        let hash: String
        let fromContract: TezosContract?
        let toContract: TezosContract?
        let amount: Amount<TezosContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<TezosContract>?
        var gasUsed: Amount<TezosContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}
