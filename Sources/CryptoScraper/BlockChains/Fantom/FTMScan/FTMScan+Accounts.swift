// FTMScan+Accounts.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension FTMScan {
    /// Returns the balance (in Fantom) of the given account
    ///
    /// - Parameter account: The Fantom account to query the balance for
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

    func cryptoAmount(forAccount ftmContract: CryptoContract) throws -> CryptoAmount {
        guard success else {
            throw FTMScanResponseError.requestFailed(result)
        }

        guard let amount = UInt128(result) else {
            throw FTMScanResponseError.invalidAmount
        }

        return .init(quantity: amount, contract: ftmContract)
    }

    // https://docs.ftmscan.com/api-endpoints/accounts#get-ftm-balance-for-a-single-address
    static func httpQuery(account: CryptoContract, apiKey: String) -> [URLQueryItem] { [
        .init(name: "module", value: "account"),
        .init(name: "action", value: "balance"),
        .init(name: "address", value: account.address),
        .init(name: "tag", value: "latest"),
        .init(name: "apiKey", value: apiKey)
    ] }
}
