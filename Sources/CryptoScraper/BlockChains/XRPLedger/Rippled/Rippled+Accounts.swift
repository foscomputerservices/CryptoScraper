// Rippled+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension Rippled {
    /// Returns the balance, in drops, of the given account, as of the latest validated ledger
    ///
    /// - Parameter account: The XRP Ledger account to query the balance for
    /// - Throws: ``RippledResponseError/requestFailed(_:)`` when the server answers with an error (an unfunded
    ///   account's `actNotFound` among them) or no result, or a Balance that is not a count of drops
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: AccountInfoResponse = try await Self.call(
            "account_info", ["account": account.address, "ledger_index": "validated"]
        )

        return try response.amount()
    }

    /// Returns XRP's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``RippledResponseError/unknownToken`` for any other contract: an issued token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw RippledResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension Rippled {
    /// `account_info`'s result: `{ "account_data": { "Account": …, "Balance": "<drops>" }, … }`
    struct AccountInfoResponse: Decodable, Sendable {
        let accountData: AccountData

        struct AccountData: Decodable, Sendable {
            let account: String
            let balance: String

            private enum CodingKeys: String, CodingKey {
                case account = "Account"
                case balance = "Balance"
            }
        }

        private enum CodingKeys: String, CodingKey {
            case accountData = "account_data"
        }

        /// The balance in XRP's main contract, counted in drops
        func amount() throws -> Amount<XRPLedgerContract> {
            guard let drops = Int128(accountData.balance) else {
                throw RippledResponseError.requestFailed("Balance \(accountData.balance) is not a count of drops")
            }
            return .init(quantity: drops, currency: XRPLedgerChain.default.mainContract)
        }
    }
}
