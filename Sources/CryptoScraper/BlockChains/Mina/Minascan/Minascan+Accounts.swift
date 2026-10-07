// Minascan+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension Minascan {
    /// Returns the balance, in nanomina, of the given account; zero when the ledger holds no account for the key
    ///
    /// - Parameter account: The Mina public key to query the balance for
    /// - Throws: ``MinascanResponseError/requestFailed(_:)`` when the node answers with errors, with no data, or with a
    ///   total that is not a count of nanomina
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let body = try JSONSerialization.data(withJSONObject: [
            "query": "query($key: PublicKey!) { account(publicKey: $key) { publicKey balance { total } } }",
            "variables": ["key": account.address]
        ] as [String: Any])
        let response: AccountResponse = try await DataFetch<URLSession>.default.send(
            data: body, to: Self.endPoint, httpMethod: "POST",
            headers: [(field: "Content-Type", value: "application/json")], locale: nil
        )

        return try response.amount()
    }

    /// Returns MINA's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``MinascanResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw MinascanResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension Minascan {
    /// The node's answer to `account(publicKey:)`: `{ "data": { "account": { "balance": { "total": "<nanomina>" } } }
    /// }`,
    /// `account` null when the ledger holds none, or `{ "errors": [{ "message": … }] }`
    struct AccountResponse: Decodable, Sendable {
        let data: ResponseData?
        let errors: [Failure]?

        struct ResponseData: Decodable, Sendable {
            let account: Account?
        }

        struct Account: Decodable, Sendable {
            let balance: Balance

            struct Balance: Decodable, Sendable {
                let total: String
            }
        }

        struct Failure: Decodable, Sendable {
            let message: String
        }

        /// The balance in MINA's main contract, counted in nanomina; zero for an account the ledger does not hold
        func amount() throws -> Amount<MinaContract> {
            if let errors, !errors.isEmpty {
                throw MinascanResponseError.requestFailed(errors.map(\.message).joined(separator: "; "))
            }
            guard let data else {
                throw MinascanResponseError.requestFailed("no data")
            }
            let total = data.account?.balance.total ?? "0"
            guard let quantity = Int128(total) else {
                throw MinascanResponseError.requestFailed("\(total) is not a count of nanomina")
            }
            return .init(quantity: quantity, currency: MinaChain.default.mainContract)
        }
    }
}
