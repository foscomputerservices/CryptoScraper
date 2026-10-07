// Filfox+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension Filfox {
    /// Returns the balance, in attoFIL, of the given address
    ///
    /// - Parameter account: The Filecoin address to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: AddressResponse = try await Self.endPoint
            .appending(path: "address").appending(path: account.address)
            .fetch()

        return try response.amount()
    }

    /// Returns FIL's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``FilfoxResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw FilfoxResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension Filfox {
    /// `/address/{address}`: `{ "address": …, "balance": "<attoFIL>", … }`
    struct AddressResponse: Decodable, Sendable {
        let address: String
        let balance: String

        /// The balance in FIL's main contract, counted in attoFIL, read by its digits
        func amount() throws -> Amount<FilecoinContract> {
            guard let quantity = Int128(balance) else {
                throw FilfoxResponseError.requestFailed("balance \(balance) is not a count of attoFIL")
            }
            return .init(quantity: quantity, currency: FilecoinChain.default.mainContract)
        }
    }
}
