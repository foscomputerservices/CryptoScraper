// Koios+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension Koios {
    /// Retrieves the ``CryptoTransaction``s for the given address: its latest transactions, newest first, each the ADA
    /// the address gained or lost in it
    ///
    /// - Parameter account: The address from which to retrieve the transactions
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let listed: [AddressTransaction] = try await Self.post("address_txs", ["_addresses": [account.address]])
        let hashes = listed.sorted { $0.blockTime > $1.blockTime }.prefix(25).map(\.txHash)
        guard !hashes.isEmpty else {
            return []
        }
        let response: [TransactionInfo] = try await Self.post("tx_info", ["_tx_hashes": hashes, "_inputs": true])

        return try TransactionInfo.cryptoTransactions(response, forAccount: account)
    }

    /// A `tx_info` answer does not name the address it was asked about, so it is read only for an address
    ///
    /// - Throws: ``KoiosResponseError/requestFailed(_:)``, always: use ``loadTransactions(from:forAccount:)``
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        throw KoiosResponseError.requestFailed("a tx_info answer is read for an address; none was given")
    }

    /// Retrieves the ``CryptoTransaction``s of one `tx_info` answer for `account`
    func loadTransactions(from data: Data, forAccount account: Contract) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: [TransactionInfo] = try data.fromJSON()
        return try TransactionInfo.cryptoTransactions(response, forAccount: account)
    }
}

extension Koios {
    /// One row of `address_txs`: `{ "tx_hash", "epoch_no", "block_height", "block_time" }`
    struct AddressTransaction: Decodable, Sendable {
        let txHash: String
        let blockTime: Int64

        private enum CodingKeys: String, CodingKey {
            case txHash = "tx_hash"
            case blockTime = "block_time"
        }
    }

    /// One row of `tx_info`: its hash, time, fee, and its inputs and outputs, each an address and a value in lovelace
    struct TransactionInfo: Decodable, Sendable {
        let txHash: String
        let txTimestamp: Int64
        let fee: String
        let inputs: [Output]
        let outputs: [Output]

        struct Output: Decodable, Sendable {
            let paymentAddr: PaymentAddress
            let value: String

            struct PaymentAddress: Decodable, Sendable {
                let bech32: String
            }

            private enum CodingKeys: String, CodingKey {
                case paymentAddr = "payment_addr"
                case value
            }
        }

        private enum CodingKeys: String, CodingKey {
            case txHash = "tx_hash"
            case txTimestamp = "tx_timestamp"
            case fee
            case inputs
            case outputs
        }

        /// One transaction per row: the ADA `account` gained (its outputs to the account less its inputs from it), from
        /// the first input not the account's to the account; or lost, from the account to the first output not its
        /// own. The fee is the transaction's, in lovelace; every listed transaction is on the ledger, so successful.
        static func cryptoTransactions(
            _ rows: [TransactionInfo], forAccount account: CardanoContract
        ) throws -> [any CryptoTransaction] {
            let coin = CardanoChain.default.mainContract!
            return try rows.map { row in
                func sum(_ outputs: [Output]) throws -> Int128 {
                    try outputs.filter { $0.paymentAddr.bech32 == account.address }.reduce(0) { total, output in
                        guard let value = Int128(output.value) else {
                            throw KoiosResponseError.requestFailed("value \(output.value) is not a count of lovelace")
                        }
                        return total + value
                    }
                }
                guard let fee = Int128(row.fee) else {
                    throw KoiosResponseError.requestFailed("fee \(row.fee) is not a count of lovelace")
                }
                let change = try sum(row.outputs) - sum(row.inputs)
                let received = change >= 0
                let other = (received ? row.inputs : row.outputs)
                    .first { $0.paymentAddr.bech32 != account.address }
                    .map { CardanoContract(address: $0.paymentAddr.bech32) }
                return MappedTransaction(
                    hash: row.txHash,
                    fromContract: received ? other : account,
                    toContract: received ? account : other,
                    amount: .init(quantity: received ? change : -change, currency: coin),
                    timeStamp: Date(timeIntervalSince1970: TimeInterval(row.txTimestamp)),
                    transactionId: row.txHash,
                    gasPrice: .init(quantity: fee, currency: coin),
                    successful: true,
                    type: "payment"
                )
            }
        }
    }
}
