// CKBExplorer+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension CKBExplorer {
    /// Retrieves the ``CryptoTransaction``s for the given address: its latest transactions, newest first, each the
    /// address's income in it
    ///
    /// - Parameter account: The address from which to retrieve the transactions
    /// - Throws: ``CKBExplorerResponseError/requestFailed(_:)`` when a row states no income in shannons or no time
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        var url = Self.endPoint.appending(path: "address_transactions").appending(path: account.address)
        url.append(queryItems: [.init(name: "page", value: "1"), .init(name: "page_size", value: "25")])
        let response: TransactionsResponse = try await Self.get(url)

        return try response.cryptoTransactions(forAccount: account)
    }

    /// An explorer answer states each transaction's income but not the address it was asked about, so it is read
    /// only for an address
    ///
    /// - Throws: ``CKBExplorerResponseError/requestFailed(_:)``, always: use ``loadTransactions(from:forAccount:)``
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        throw CKBExplorerResponseError.requestFailed(
            "an address's transactions are read for an address; none was given"
        )
    }

    /// Retrieves the ``CryptoTransaction``s of one `/address_transactions/{address}` answer for `account`
    /// - Throws: ``CKBExplorerResponseError/requestFailed(_:)`` when a row states no income in shannons or no time
    func loadTransactions(from data: Data, forAccount account: Contract) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: TransactionsResponse = try data.fromJSON()
        return try response.cryptoTransactions(forAccount: account)
    }
}

extension CKBExplorer {
    /// `/address_transactions/{address}`: `{ "data": [{ "type": "ckb_transactions", "attributes": {
    /// "transaction_hash", "block_timestamp": "<ms>", "income": <shannons>, "is_cellbase", "display_inputs",
    /// "display_outputs" } }], "meta" }`; the inputs and outputs shown are a few of each, never all
    struct TransactionsResponse: Decodable, Sendable {
        let data: [Row]

        struct Row: Decodable, Sendable {
            let attributes: Attributes

            struct Attributes: Decodable, Sendable {
                let transactionHash: String
                let blockTimestamp: String
                let income: Decimal
                let isCellbase: Bool
                let displayInputs: [Cell]
                let displayOutputs: [Cell]

                struct Cell: Decodable, Sendable {
                    let addressHash: String?

                    private enum CodingKeys: String, CodingKey {
                        case addressHash = "address_hash"
                    }
                }

                private enum CodingKeys: String, CodingKey {
                    case transactionHash = "transaction_hash"
                    case blockTimestamp = "block_timestamp"
                    case income
                    case isCellbase = "is_cellbase"
                    case displayInputs = "display_inputs"
                    case displayOutputs = "display_outputs"
                }
            }
        }

        /// One transaction per row: the address's income, the size of its change; a gain from the first input shown
        /// that is not the address (none for a cellbase), a loss to the first output shown that is not the address.
        /// The answer states no fee; every listed transaction is committed, so successful.
        func cryptoTransactions(forAccount account: NervosContract) throws -> [any CryptoTransaction] {
            let coin = NervosChain.default.mainContract!
            return try data.map { row in
                let attributes = row.attributes
                guard
                    let income = Int128(attributes.income.description),
                    let milliseconds = Int64(attributes.blockTimestamp)
                else {
                    throw CKBExplorerResponseError.requestFailed(
                        "transaction \(attributes.transactionHash) states no income in shannons"
                    )
                }
                let received = income >= 0
                let other = (received ? attributes.displayInputs : attributes.displayOutputs)
                    .compactMap(\.addressHash).first { $0 != account.address }
                    .map { NervosContract(address: $0) }
                return MappedTransaction(
                    hash: attributes.transactionHash,
                    fromContract: received ? other : account,
                    toContract: received ? account : other,
                    amount: .init(quantity: received ? income : -income, currency: coin),
                    timeStamp: Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000),
                    transactionId: attributes.transactionHash,
                    gasPrice: nil,
                    successful: true,
                    type: attributes.isCellbase ? "cellbase" : "transfer"
                )
            }
        }
    }
}
