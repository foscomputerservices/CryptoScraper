// ArweaveGateway+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension ArweaveGateway {
    /// Returns the balance, in winston, of the given wallet
    ///
    /// - Parameter account: The Arweave wallet to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let url = Self.endPoint.appending(path: "wallet").appending(path: account.address).appending(path: "balance")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let status = (response as? HTTPURLResponse)?.statusCode, status == 200 else {
            throw ArweaveGatewayResponseError.requestFailed(
                "the gateway answered \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            )
        }

        return try Self.balance(from: data)
    }

    /// Returns AR's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``ArweaveGatewayResponseError/unknownToken`` for any other contract: a token's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw ArweaveGatewayResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }
}

extension ArweaveGateway {
    /// `/wallet/{address}/balance`'s answer, plain text: the balance in winston, its digits alone
    static func balance(from data: Data) throws -> Amount<ArweaveContract> {
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let quantity = Int128(text) else {
            throw ArweaveGatewayResponseError.requestFailed("\(text) is not a count of winston")
        }
        return .init(quantity: quantity, currency: ArweaveChain.default.mainContract)
    }
}
