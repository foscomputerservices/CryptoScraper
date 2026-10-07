// Horizon+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension Horizon {
    /// Retrieves the ``CryptoTransaction``s for the given account: its latest payments in XLM, newest first
    ///
    /// - Parameter account: The account from which to retrieve the transactions
    /// - Throws: ``HorizonResponseError/requestFailed(_:)`` for Horizon's problem answer
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        do {
            let response: PaymentsResponse = try await Self.get(Self.endPoint.appending(path: "accounts")
                .appending(path: account.address)
                .appending(path: "payments")
                .appending(queryItems: [.init(name: "limit", value: "20"), .init(name: "order", value: "desc")])
            )

            return response.cryptoTransactions()
        } catch let problem as Problem {
            throw problem.horizonError
        }
    }

    /// Retrieves the ``CryptoTransaction``s of one `/accounts/{id}/payments` answer, as Horizon sends it
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: PaymentsResponse = try data.fromJSON()
        return response.cryptoTransactions()
    }
}

extension Horizon {
    /// `/accounts/{id}/payments`: its records, each a payment or an account's creation
    struct PaymentsResponse: Decodable, Sendable {
        let records: [Record]

        struct Embedded: Decodable, Sendable {
            let records: [Record]
        }

        struct Record: Decodable, Sendable {
            let type: String
            let createdAt: Date
            let transactionHash: String
            let transactionSuccessful: Bool
            let from: String?
            let to: String?
            let amount: String?
            let assetType: String?
            let funder: String?
            let account: String?
            let startingBalance: String?

            private enum CodingKeys: String, CodingKey {
                case type
                case createdAt = "created_at"
                case transactionHash = "transaction_hash"
                case transactionSuccessful = "transaction_successful"
                case from
                case to
                case amount
                case assetType = "asset_type"
                case funder
                case account
                case startingBalance = "starting_balance"
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.type = try container.decode(String.self, forKey: .type)
                let created = try container.decode(String.self, forKey: .createdAt)
                guard let date = ISO8601DateFormatter().date(from: created) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .createdAt, in: container, debugDescription: "Not an ISO 8601 time: \(created)"
                    )
                }
                self.createdAt = date
                self.transactionHash = try container.decode(String.self, forKey: .transactionHash)
                self.transactionSuccessful = try container.decode(Bool.self, forKey: .transactionSuccessful)
                self.from = try container.decodeIfPresent(String.self, forKey: .from)
                self.to = try container.decodeIfPresent(String.self, forKey: .to)
                self.amount = try container.decodeIfPresent(String.self, forKey: .amount)
                self.assetType = try container.decodeIfPresent(String.self, forKey: .assetType)
                self.funder = try container.decodeIfPresent(String.self, forKey: .funder)
                self.account = try container.decodeIfPresent(String.self, forKey: .account)
                self.startingBalance = try container.decodeIfPresent(String.self, forKey: .startingBalance)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case embedded = "_embedded"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.records = try container.decode(Embedded.self, forKey: .embedded).records
        }

        /// One transaction per XLM payment and per account creation (its starting balance); a payment in an issued
        /// asset, and any other record, is left out
        func cryptoTransactions() -> [any CryptoTransaction] {
            let coin = StellarChain.default.mainContract!
            return records.compactMap { record -> (any CryptoTransaction)? in
                let from: String?, to: String?, amount: String?
                switch record.type {
                case "payment" where record.assetType == "native":
                    (from, to, amount) = (record.from, record.to, record.amount)
                case "create_account":
                    (from, to, amount) = (record.funder, record.account, record.startingBalance)
                default:
                    return nil
                }
                guard let amount, let stroops = Horizon.stroops(amount) else {
                    return nil
                }
                return MappedTransaction(
                    hash: record.transactionHash,
                    fromContract: from.map { StellarContract(address: $0) },
                    toContract: to.map { StellarContract(address: $0) },
                    amount: .init(quantity: stroops, currency: coin),
                    timeStamp: record.createdAt,
                    transactionId: record.transactionHash,
                    successful: record.transactionSuccessful,
                    type: record.type
                )
            }
        }
    }

    private struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = StellarContract

        let hash: String
        let fromContract: StellarContract?
        let toContract: StellarContract?
        let amount: Amount<StellarContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        var gasPrice: Amount<StellarContract>? { nil }
        var gasUsed: Amount<StellarContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}
