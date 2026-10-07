// CKBExplorer+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension CKBExplorer {
    /// Returns the balance, in shannons, of the given address
    ///
    /// - Parameter account: The CKB address to query the balance for
    /// - Throws: ``CKBExplorerResponseError/requestFailed(_:)`` when the answer states no balance in shannons
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: AddressResponse = try await Self.get(
            Self.endPoint.appending(path: "addresses").appending(path: account.address)
        )

        return try response.amount()
    }

    /// Returns CKB's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``CKBExplorerResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw CKBExplorerResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension CKBExplorer {
    /// `/addresses/{address}`: `{ "data": [{ "type": "address", "attributes": { "balance": "<shannons>", … } }] }`
    struct AddressResponse: Decodable, Sendable {
        let data: [Row]

        struct Row: Decodable, Sendable {
            let attributes: Attributes

            struct Attributes: Decodable, Sendable {
                let balance: String
            }
        }

        /// The balance in CKB's main contract, counted in shannons, read by its digits
        func amount() throws -> Amount<NervosContract> {
            guard let text = data.first?.attributes.balance, let quantity = Int128(text) else {
                throw CKBExplorerResponseError.requestFailed("no balance in shannons")
            }
            return .init(quantity: quantity, currency: NervosChain.default.mainContract)
        }
    }
}
