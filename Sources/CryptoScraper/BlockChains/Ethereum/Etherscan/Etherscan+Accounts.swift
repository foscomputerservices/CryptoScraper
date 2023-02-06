// Etherscan+Accounts.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension Etherscan {
    func getAccountBalance(address: CryptoContract) async throws -> CryptoAmount {
        let response: AccountResponse = try await Self.endPiont.appending(
            queryItems: AccountResponse.httpQuery(address: address, apiKey: Self.apiKey)
        ).fetch()

        return try response.cryptoAmount(ethContract: address.chain.mainContract)
    }
}

private struct AccountResponse: Decodable {
    let status: String
    let message: String
    let result: String

    var success: Bool {
        status == "1" || message == "OK"
    }

    func cryptoAmount(ethContract: CryptoContract) throws -> CryptoAmount {
        guard success else {
            throw EtherscanResponseError.requestFailed
        }

        guard let amount = Int64(result) else {
            throw EtherscanResponseError.invalidAmount
        }

        return .init(quantity: amount, contract: ethContract)
    }

    // https://docs.etherscan.io/api-endpoints/accounts#get-ether-balance-for-a-single-address
    static func httpQuery(address: CryptoContract, apiKey: String) -> [URLQueryItem] { [
        .init(name: "module", value: "account"),
        .init(name: "action", value: "balance"),
        .init(name: "address", value: address.address),
        .init(name: "tag", value: "latest"),
        .init(name: "apiKey", value: apiKey)
    ] }
}
