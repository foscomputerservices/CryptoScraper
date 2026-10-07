// SolanaRPC+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension SolanaRPC {
    /// Returns the balance, in lamports, of the given account
    ///
    /// - Parameter account: The Solana account to query the balance for
    /// - Throws: ``SolanaRPCResponseError/requestFailed(_:)`` when the node answers with an error or no result
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: BalanceResponse = try await Self.call("getBalance", [account.address])

        return response.amount()
    }

    /// Returns SOL's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``SolanaRPCResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw SolanaRPCResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension SolanaRPC {
    /// `getBalance`'s result: `{ "context": { "slot": … }, "value": <lamports> }`
    struct BalanceResponse: Decodable, Sendable {
        let value: UInt64

        /// The balance in SOL's main contract, counted in lamports
        func amount() -> Amount<SolanaContract> {
            .init(quantity: Int128(value), currency: SolanaChain.default.mainContract)
        }
    }
}
