// VeChainThor+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public extension VeChainThor {
    /// Returns the account's VET, the chain's coin, in wei
    ///
    /// - Parameter account: The VeChain account to query the balance for
    /// - Throws: ``VeChainThorResponseError/requestFailed(_:)`` when the balance is not a count of wei in hex
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        try await getBalance(forToken: account.chain.mainContract, forAccount: account)
    }

    /// Returns the account's VET or VTHO, in wei: the node states both in one answer, VET as its `balance` and VTHO
    /// as its `energy`
    ///
    /// - Throws: ``VeChainThorResponseError/unknownToken`` for any other contract: a token's balance is not read;
    ///   ``VeChainThorResponseError/requestFailed(_:)`` when the balance or energy is not a count of wei in hex
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken || contract.address == VeChainChain.vthoContractAddress else {
            throw VeChainThorResponseError.unknownToken
        }
        let response: AccountResponse = try await Self.endPoint
            .appending(path: "accounts").appending(path: account.address)
            .fetch()

        return try response.amount(of: contract)
    }
}

extension VeChainThor {
    /// `/accounts/{address}`: `{ "balance": "0x<wei of VET>", "energy": "0x<wei of VTHO>", "hasCode": … }`
    struct AccountResponse: Decodable, Sendable {
        let balance: String
        let energy: String

        /// The balance of `contract`, VET or VTHO, counted in wei
        func amount(of contract: VeChainContract) throws -> Amount<VeChainContract> {
            let text = contract.address == VeChainChain.vthoContractAddress ? energy : balance
            guard let quantity = VeChainThor.quantity(hex: text) else {
                throw VeChainThorResponseError.requestFailed("\(text) is not a count of wei")
            }
            return .init(quantity: quantity, currency: contract)
        }
    }
}
