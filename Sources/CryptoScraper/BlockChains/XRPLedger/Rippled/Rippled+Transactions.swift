// Rippled+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension Rippled {
    /// Retrieves the ``CryptoTransaction``s for the given account, its latest first
    ///
    /// - Parameter account: The account from which to retrieve the transactions
    /// - Throws: ``RippledResponseError/requestFailed(_:)`` when the server answers with an error or no result
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let response: AccountTxResponse = try await Self.call(
            "account_tx", ["account": account.address, "limit": 20, "api_version": 1]
        )

        return response.cryptoTransactions()
    }

    /// Retrieves the ``CryptoTransaction``s of one `account_tx` answer, as the server sends it
    /// - Throws: ``RippledResponseError/requestFailed(_:)`` when the envelope holds an error or no result
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: Response<AccountTxResponse> = try data.fromJSON()
        return try response.value().cryptoTransactions()
    }
}

extension Rippled {
    /// `account_tx`'s result (API version 1): each transaction with its metadata
    struct AccountTxResponse: Decodable, Sendable {
        let transactions: [Entry]

        struct Entry: Decodable, Sendable {
            let tx: Transaction
            let meta: Meta
        }

        struct Transaction: Decodable, Sendable {
            let account: String
            let destination: String?
            let fee: String
            let hash: String
            let date: Int64
            let transactionType: String

            private enum CodingKeys: String, CodingKey {
                case account = "Account"
                case destination = "Destination"
                case fee = "Fee"
                case hash
                case date
                case transactionType = "TransactionType"
            }
        }

        struct Meta: Decodable, Sendable {
            let transactionResult: String
            let deliveredAmount: DeliveredAmount?

            private enum CodingKeys: String, CodingKey {
                case transactionResult = "TransactionResult"
                case deliveredAmount = "delivered_amount"
            }
        }

        /// `delivered_amount`: drops of XRP as a string, or an issued token's amount as an object
        enum DeliveredAmount: Decodable, Sendable {
            case drops(String)
            case issued

            init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let drops = try? container.decode(String.self) {
                    self = .drops(drops)
                } else {
                    self = .issued
                }
            }
        }

        /// The seconds from the Unix epoch to the XRP Ledger's, 2000-01-01 00:00 UTC
        static let rippleEpoch: TimeInterval = 946_684_800

        /// One transaction per entry: the XRP delivered (zero when none was, or an issued token was), the fee in
        /// drops, the ledger's time, and success when the result is `tesSUCCESS`
        func cryptoTransactions() -> [any CryptoTransaction] {
            let coin = XRPLedgerChain.default.mainContract!
            return transactions.map { entry in
                var delivered: Int128 = 0
                if case .drops(let drops) = entry.meta.deliveredAmount {
                    delivered = Int128(drops) ?? 0
                }
                return MappedTransaction(
                    hash: entry.tx.hash,
                    fromContract: XRPLedgerContract(address: entry.tx.account),
                    toContract: entry.tx.destination.map { XRPLedgerContract(address: $0) },
                    amount: .init(quantity: delivered, currency: coin),
                    timeStamp: Date(timeIntervalSince1970: Self.rippleEpoch + TimeInterval(entry.tx.date)),
                    transactionId: entry.tx.hash,
                    gasPrice: Int128(entry.tx.fee).map { .init(quantity: $0, currency: coin) },
                    successful: entry.meta.transactionResult == "tesSUCCESS",
                    type: entry.tx.transactionType
                )
            }
        }
    }

    private struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = XRPLedgerContract

        let hash: String
        let fromContract: XRPLedgerContract?
        let toContract: XRPLedgerContract?
        let amount: Amount<XRPLedgerContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<XRPLedgerContract>?
        var gasUsed: Amount<XRPLedgerContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}
