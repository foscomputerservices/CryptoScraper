// SiaScan.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A ``CryptoScanner`` implementation for SiaScan's public explorer API (explored), `api.siascan.com`, keyless
///
/// Reads SC: an address's unspent siacoins (`/addresses/{address}/balance`) and its payout events
/// (`/addresses/{address}/events`), each a siacoin output paid to it. An event of any other kind fails the whole read
/// (``getTransactions(forAccount:)`` throws), and a siafund's balance is not read.
public struct SiaScan: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = SiaContract

    /// SiaScan's public mainnet API
    public static let endPoint: URL = .init(string: "https://api.siascan.com")!

    /// "SiaScan"
    public let userReadableName: String = "SiaScan"

    public init() {}
}

public enum SiaScanResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    /// A token's balance is not read by this scanner
    case unknownToken

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown."
        case .unknownToken:
            return "Unable to read any balance on Sia but SC's"
        }
    }
}

extension SiaScan {
    /// One transaction as the scanner maps it
    struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = SiaContract

        let hash: String
        let fromContract: SiaContract?
        let toContract: SiaContract?
        let amount: Amount<SiaContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<SiaContract>?
        var gasUsed: Amount<SiaContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        let type: String?
    }
}

public extension SiaScan {
    /// Returns the address's unspent siacoins, in hastings
    ///
    /// - Parameter account: The Sia address to query the balance for
    /// - Throws: ``SiaScanResponseError/requestFailed(_:)`` when the unspent siacoins are not a count of hastings
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: BalanceResponse = try await DataFetch<URLSession>.default.send(
            to: Self.endPoint.appending(path: "addresses").appending(path: account.address).appending(path: "balance"),
            httpMethod: "GET", headers: nil, locale: nil
        )

        return try response.amount()
    }

    /// Returns SC's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``SiaScanResponseError/unknownToken`` for any other contract
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw SiaScanResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }

    /// Retrieves the ``CryptoTransaction``s for the given address: its latest payout events, newest first
    ///
    /// - Throws: ``SiaScanResponseError/requestFailed(_:)`` when an event is of a kind not read: the list is never
    ///   answered short
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        var url = Self.endPoint.appending(path: "addresses").appending(path: account.address).appending(path: "events")
        url.append(queryItems: [.init(name: "limit", value: "25")])
        let response: [Event] = try await DataFetch<URLSession>.default.send(
            to: url, httpMethod: "GET", headers: nil, locale: nil
        )

        return try Event.cryptoTransactions(response)
    }

    /// Retrieves the ``CryptoTransaction``s of one `/addresses/{address}/events` answer
    /// - Throws: ``SiaScanResponseError/requestFailed(_:)`` when an event is not a payout, or states no hastings or no
    ///   time
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: [Event] = try data.fromJSON()
        return try Event.cryptoTransactions(response)
    }
}

extension SiaScan {
    /// `/addresses/{address}/balance`: `{ "unspentSiacoins": "<hastings>", "immatureSiacoins", "unspentSiafunds" }`
    struct BalanceResponse: Decodable, Sendable {
        let unspentSiacoins: String

        /// The unspent siacoins in SC's main contract, counted in hastings, read by their digits
        func amount() throws -> Amount<SiaContract> {
            guard let quantity = Int128(unspentSiacoins) else {
                throw SiaScanResponseError.requestFailed("balance \(unspentSiacoins) is not a count of hastings")
            }
            return .init(quantity: quantity, currency: SiaChain.default.mainContract)
        }
    }

    /// One event: `{ "id", "type", "timestamp", "data": { "siacoinElement": { "siacoinOutput": { "value": "<hastings>",
    /// "address" } } } }` for a payout (`siafundClaim`, `miner`, `foundation`); any other kind's data is another shape
    struct Event: Decodable, Sendable {
        let id: String
        let type: String
        let timestamp: String
        let data: EventData

        struct EventData: Decodable, Sendable {
            let siacoinElement: Element?

            struct Element: Decodable, Sendable {
                let siacoinOutput: Output

                struct Output: Decodable, Sendable {
                    let value: String
                    let address: String
                }
            }
        }

        /// One transaction per payout event: its siacoin output, paid to its address from no one, at the event's time
        ///
        /// - Throws: ``SiaScanResponseError/requestFailed(_:)`` for an event that is not a payout
        static func cryptoTransactions(_ events: [Event]) throws -> [any CryptoTransaction] {
            let coin = SiaChain.default.mainContract!
            return try events.map { event in
                guard let output = event.data.siacoinElement?.siacoinOutput else {
                    throw SiaScanResponseError.requestFailed("an event of type \(event.type) is not read")
                }
                guard let quantity = Int128(output.value),
                      let time = try? Date(event.timestamp, strategy: .iso8601) else {
                    throw SiaScanResponseError.requestFailed("event \(event.id) states no hastings or no time")
                }
                return MappedTransaction(
                    hash: event.id,
                    fromContract: nil,
                    toContract: SiaContract(address: output.address),
                    amount: .init(quantity: quantity, currency: coin),
                    timeStamp: time,
                    transactionId: event.id,
                    gasPrice: nil,
                    successful: true,
                    type: event.type
                )
            }
        }
    }
}
