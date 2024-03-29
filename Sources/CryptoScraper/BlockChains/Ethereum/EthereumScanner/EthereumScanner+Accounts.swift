// EthereumScanner+Accounts.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension EthereumScanner {
    /// Returns the balance (in Ethereum) of the given account
    ///
    /// - Parameter account: The Ethereum account to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: AccountResponse = try await Self.endPoint.appending(
            queryItems: AccountResponse.httpQuery(account: account, apiKey: Self.requireApiKey())
        ).fetch()

        return try response.amount(
            forAccount: account.chain.mainContract
        )
    }
}

private struct AccountResponse: Decodable {
    let status: String
    let message: String
    let result: String

    var success: Bool {
        status == "1" || message == "OK"
    }

    func amount<C: CryptoContract>(forAccount ethContract: C) throws -> Amount<C> {
        guard success else {
            throw EthereumScannerResponseError.requestFailed(result)
        }

        guard let amount = UInt128(result) else {
            throw EthereumScannerResponseError.invalidAmount
        }

        return .init(quantity: amount, currency: ethContract)
    }

    // https://docs.etherscan.io/api-endpoints/accounts#get-ether-balance-for-a-single-address
    static func httpQuery(account: any CryptoContract, apiKey: String) -> [URLQueryItem] { [
        .init(name: "module", value: "account"),
        .init(name: "action", value: "balance"),
        .init(name: "address", value: account.address),
        .init(name: "tag", value: "latest"),
        .init(name: "apiKey", value: apiKey)
    ] }
}
