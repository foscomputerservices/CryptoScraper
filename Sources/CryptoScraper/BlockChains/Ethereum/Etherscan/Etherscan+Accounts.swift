// Etherscan+Accounts.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension Etherscan {
    /// Returns the balance (in Ethereum) of the given account
    ///
    /// - Parameter account: The Ethereum account to query the balance for
    func getBalance(forAccount account: CryptoContract) async throws -> CryptoAmount {
        let response: AccountResponse = try await Self.endPiont.appending(
            queryItems: AccountResponse.httpQuery(account: account, apiKey: Self.apiKey)
        ).fetch()

        return try response.cryptoAmount(forAccount: account.chain.mainContract)
    }
}

private struct AccountResponse: Decodable {
    let status: String
    let message: String
    let result: String

    var success: Bool {
        status == "1" || message == "OK"
    }

    func cryptoAmount(forAccount ethContract: CryptoContract) throws -> CryptoAmount {
        guard success else {
            throw EtherscanResponseError.requestFailed(result)
        }

        guard let amount = Int64(result) else {
            throw EtherscanResponseError.invalidAmount
        }

        return .init(quantity: amount, contract: ethContract)
    }

    // https://docs.etherscan.io/api-endpoints/accounts#get-ether-balance-for-a-single-address
    static func httpQuery(account: CryptoContract, apiKey: String) -> [URLQueryItem] { [
        .init(name: "module", value: "account"),
        .init(name: "action", value: "balance"),
        .init(name: "address", value: account.address),
        .init(name: "tag", value: "latest"),
        .init(name: "apiKey", value: apiKey)
    ] }
}
