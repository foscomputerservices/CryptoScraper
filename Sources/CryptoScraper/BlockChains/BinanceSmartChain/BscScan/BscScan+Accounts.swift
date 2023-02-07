// BscScan+Accounts.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension BscScan {
    /// Returns the balance (in BNB) of the given account
    ///
    /// - Parameter account: The Bsc account to query the balance for
    func getBalance(forAccount account: CryptoContract) async throws -> CryptoAmount {
        let response: AccountResponse = try await Self.endPoint.appending(
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

    func cryptoAmount(forAccount bnbContract: CryptoContract) throws -> CryptoAmount {
        guard success else {
            throw BscScanResponseError.requestFailed(result)
        }

        guard let amount = UInt128(result) else {
            throw BscScanResponseError.invalidAmount
        }

        return .init(quantity: amount, contract: bnbContract)
    }

    // https://docs.bscscan.com/api-endpoints/accounts#get-bnb-balance-for-a-single-address
    static func httpQuery(account: CryptoContract, apiKey: String) -> [URLQueryItem] { [
        .init(name: "module", value: "account"),
        .init(name: "action", value: "balance"),
        .init(name: "address", value: account.address),
        .init(name: "tag", value: "latest"),
        .init(name: "apiKey", value: apiKey)
    ] }
}
