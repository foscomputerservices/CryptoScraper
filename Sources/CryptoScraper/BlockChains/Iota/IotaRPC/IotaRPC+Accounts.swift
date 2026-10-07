// IotaRPC+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension IotaRPC {
    /// Returns the balance, in nanos, of the given address
    ///
    /// - Parameter account: The IOTA address to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: BalanceResponse = try await Self.call("iotax_getBalance", [account.address, Self.coinType])

        return try response.amount()
    }

    /// Returns IOTA's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``IotaRPCResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw IotaRPCResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension IotaRPC {
    /// `iotax_getBalance`'s result: `{ "coinType": "0x2::iota::IOTA", "totalBalance": "<nanos>", … }`
    struct BalanceResponse: Decodable, Sendable {
        let coinType: String
        let totalBalance: String

        /// The balance in IOTA's main contract, counted in nanos, read by its digits
        func amount() throws -> Amount<IotaContract> {
            guard coinType == IotaRPC.coinType, let quantity = Int128(totalBalance) else {
                throw IotaRPCResponseError.requestFailed("balance \(totalBalance) of \(coinType) is not a count of nanos")
            }
            return .init(quantity: quantity, currency: IotaChain.default.mainContract)
        }
    }
}
