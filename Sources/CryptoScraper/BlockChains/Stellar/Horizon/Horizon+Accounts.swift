// Horizon+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension Horizon {
    /// Returns the native balance, in stroops, of the given account
    ///
    /// - Parameter account: The Stellar account to query the balance for
    /// - Throws: ``HorizonResponseError/requestFailed(_:)`` for Horizon's problem answer (an unfunded account's 404
    ///   among them), or when the account states no native balance or one that is not an amount
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        do {
            let response: AccountResponse = try await Self.get(Self.endPoint.appending(path: "accounts")
                .appending(path: account.address)
            )

            return try response.amount()
        } catch let problem as Problem {
            throw problem.horizonError
        }
    }

    /// Returns XLM's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``HorizonResponseError/unknownToken`` for any other contract: an issued asset's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw HorizonResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension Horizon {
    /// `/accounts/{id}`: the account's balances, the native one among them
    struct AccountResponse: Decodable, Sendable {
        let accountId: String
        let balances: [Balance]

        struct Balance: Decodable, Sendable {
            let balance: String
            let assetType: String

            private enum CodingKeys: String, CodingKey {
                case balance
                case assetType = "asset_type"
            }
        }

        private enum CodingKeys: String, CodingKey {
            case accountId = "account_id"
            case balances
        }

        /// The native balance in XLM's main contract, counted in stroops
        func amount() throws -> Amount<StellarContract> {
            guard let native = balances.first(where: { $0.assetType == "native" }) else {
                throw HorizonResponseError.requestFailed("no native balance for \(accountId)")
            }
            guard let stroops = Horizon.stroops(native.balance) else {
                throw HorizonResponseError.requestFailed("balance \(native.balance) is not an amount")
            }
            return .init(quantity: stroops, currency: StellarChain.default.mainContract)
        }
    }
}
