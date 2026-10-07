// NearRPC+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension NearRPC {
    /// Returns the balance, in yoctoNEAR, of the given account: its `amount`, the unlocked balance
    ///
    /// - Parameter account: The NEAR account to query the balance for
    /// - Throws: ``NearRPCResponseError/requestFailed(_:)`` when the node answers with an error or no result, or with
    ///   an amount that is not a count of yoctoNEAR
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: ViewAccountResponse = try await Self.call("query", [
            "request_type": "view_account", "finality": "final", "account_id": account.address
        ])

        return try response.amount()
    }

    /// Returns NEAR's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``NearRPCResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw NearRPCResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension NearRPC {
    /// `view_account`'s result: `{ "amount": "<yoctoNEAR>", "locked": "<yoctoNEAR>", "code_hash", … }`
    struct ViewAccountResponse: Decodable, Sendable {
        let yocto: String

        private enum CodingKeys: String, CodingKey {
            case yocto = "amount"
        }

        /// The balance in NEAR's main contract, counted in yoctoNEAR, read by its digits
        func amount() throws -> Amount<NearContract> {
            guard let quantity = Int128(yocto) else {
                throw NearRPCResponseError.requestFailed("balance \(yocto) is not a count of yoctoNEAR")
            }
            return .init(quantity: quantity, currency: NearChain.default.mainContract)
        }
    }
}
