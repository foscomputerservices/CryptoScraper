// CosmosLCD+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension CosmosLCD {
    /// Retrieves the ``CryptoTransaction``s that paid the given address: its latest 20, newest first, each the coin
    /// its balance changed by
    ///
    /// The search is asked as both `query` (the Cosmos SDK's parameter from v0.50) and `events` (before v0.50); each
    /// LCD reads its own and ignores the other.
    ///
    /// - Parameter account: The address from which to retrieve the transactions
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let search = "transfer.recipient='\(account.address)'"
        let response: TxsResponse = try await endPoint
            .appending(path: "cosmos").appending(path: "tx").appending(path: "v1beta1").appending(path: "txs")
            .appending(queryItems: [
                .init(name: "query", value: search),
                .init(name: "events", value: search),
                .init(name: "limit", value: "20"),
                .init(name: "order_by", value: "ORDER_BY_DESC")
            ])
            .fetch()

        return try response.cryptoTransactions(of: account, denom: denom)
    }

    /// An LCD's answer does not name the address it was asked about, so no transaction is read from it alone
    ///
    /// - Throws: ``CosmosLCDResponseError/requestFailed(_:)``, always; ``loadTransactions(from:forAccount:)`` reads an
    ///   answer for the address it was asked about
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        throw CosmosLCDResponseError.requestFailed(
            "an LCD's transactions do not name the address they were asked for; read them for an address"
        )
    }

    /// Retrieves the ``CryptoTransaction``s of one `/cosmos/tx/v1beta1/txs` answer, asked about `account`
    ///
    /// - Parameters:
    ///   - data: The LCD's answer
    ///   - account: The address the answer was asked about
    func loadTransactions(from data: Data, forAccount account: Contract) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: TxsResponse = try data.fromJSON()
        return try response.cryptoTransactions(of: account, denom: denom)
    }
}

extension CosmosLCD {
    /// `/cosmos/tx/v1beta1/txs`: `{ "tx_responses": [ { "txhash", "code", "timestamp", "tx": { "body": { "messages" },
    /// "auth_info": { "fee": { "amount" } } }, "events": [ { "type", "attributes": [ { "key", "value" } ] } ] } ],
    /// "total" }`
    struct TxsResponse: Decodable, Sendable {
        let txResponses: [TxResponse]

        struct TxResponse: Decodable, Sendable {
            let txhash: String
            let code: Int
            let timestamp: String
            let tx: Tx?
            let events: [Event]

            struct Tx: Decodable, Sendable {
                let body: Body?
                let authInfo: AuthInfo?

                struct Body: Decodable, Sendable {
                    let messages: [Message]

                    struct Message: Decodable, Sendable {
                        let type: String?

                        private enum CodingKeys: String, CodingKey {
                            case type = "@type"
                        }
                    }
                }

                struct AuthInfo: Decodable, Sendable {
                    let fee: Fee?

                    struct Fee: Decodable, Sendable {
                        let amount: [Coin]
                    }
                }

                private enum CodingKeys: String, CodingKey {
                    case body
                    case authInfo = "auth_info"
                }
            }

            struct Event: Decodable, Sendable {
                let type: String
                let attributes: [Attribute]

                struct Attribute: Decodable, Sendable {
                    let key: String
                    let value: String?
                }

                /// The attribute `key`'s value
                func value(_ key: String) -> String? {
                    attributes.first { $0.key == key }?.value
                }
            }
        }

        private enum CodingKeys: String, CodingKey {
            case txResponses = "tx_responses"
        }

        /// One transaction per transaction: the size of `account`'s balance change in `denom` over the transaction's
        /// `transfer` events, received when it grew (from the first sender that paid the address), sent when it
        /// shrank (to the first recipient it paid); the fee is the one paid in `denom`; success is code 0
        func cryptoTransactions(of account: Contract, denom: String) throws -> [any CryptoTransaction] {
            let chain = Contract.Chain.default
            let address = account.address
            return try txResponses.map { response in
                guard let timeStamp = try? Date(response.timestamp, strategy: .iso8601) else {
                    throw CosmosLCDResponseError.requestFailed("time \(response.timestamp) is not ISO 8601")
                }
                let transfers = try response.events.filter { $0.type == "transfer" }.compactMap { event in
                    try Self.transfer(event, denom: denom)
                }
                let received = transfers.filter { $0.recipient == address }
                let sent = transfers.filter { $0.sender == address }
                let change = received.reduce(Int128(0)) { $0 + $1.quantity }
                    - sent.reduce(Int128(0)) { $0 + $1.quantity }
                let fee = try response.tx?.authInfo?.fee?.amount.first { $0.denom == denom }.map { coin in
                    guard let quantity = Int128(coin.amount) else {
                        throw CosmosLCDResponseError.requestFailed("fee \(coin.amount) is not a count of \(denom)")
                    }
                    return Amount<Contract>(quantity: quantity, currency: chain.mainContract)
                }
                let other = change >= 0 ? received.first?.sender : sent.first?.recipient
                return MappedTransaction(
                    hash: response.txhash,
                    fromContract: change >= 0 ? other.map { Contract(address: $0) } : account,
                    toContract: change >= 0 ? account : other.map { Contract(address: $0) },
                    amount: .init(quantity: Int128(change.magnitude), currency: chain.mainContract),
                    timeStamp: timeStamp,
                    transactionId: response.txhash,
                    gasPrice: fee,
                    successful: response.code == 0,
                    type: response.tx?.body?.messages.first?.type
                )
            }
        }

        /// One `transfer` event's sender, recipient and amount in `denom`; `nil` when it moved none of `denom`
        ///
        /// The amount is the Cosmos SDK's coins text, `<count><denom>` joined by commas: `500000000uatom`.
        private static func transfer(
            _ event: TxResponse.Event, denom: String
        ) throws -> (sender: String?, recipient: String?, quantity: Int128)? {
            guard let coins = event.value("amount") else {
                return nil
            }
            for coin in coins.split(separator: ",") where coin.hasSuffix(denom) {
                let count = coin.dropLast(denom.count)
                guard !count.isEmpty, count.allSatisfy(\.isASCII), count.allSatisfy(\.isNumber) else {
                    continue
                }
                guard let quantity = Int128(String(count)) else {
                    throw CosmosLCDResponseError.requestFailed("amount \(coin) is not a count of \(denom)")
                }
                return (event.value("sender"), event.value("recipient"), quantity)
            }
            return nil
        }
    }
}
