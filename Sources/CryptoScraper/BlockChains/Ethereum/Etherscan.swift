// Etherscan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct Etherscan: CryptoScanner {
    static let endPiont: URL = .init(string: "https://api.etherscan.io/api")!
    static var apiKey: String {
        guard let key = ProcessInfo.processInfo.environment["ETHER_SCAN_KEY"] else {
            fatalError("ETHER_SCAN_KEY is not set in the environment")
        }

        return key
    }

    func getAccountBalance(address: CryptoContract) async throws -> CryptoAmount {
        let dataFetch = FoundationDataFetch.default
        let url = Self.endPiont.appending(
            queryItems: AccountResponse.httpQuery(address: address, apiKey: Self.apiKey)
        )

        let response: AccountResponse = try await dataFetch.fetch(url)
        return try response.cryptoAmount(ethContract: address.chain.mainContract)
    }
}

private enum AccountResponseError: Error {
    case requestFailed
    case invalidAmount
}

private struct AccountResponse: Codable {
    let status: String
    let message: String
    let result: String

    func cryptoAmount(ethContract: CryptoContract) throws -> CryptoAmount {
        guard success else {
            throw AccountResponseError.requestFailed
        }

        guard let amount = Int64(result) else {
            throw AccountResponseError.invalidAmount
        }

        return .init(quantity: amount, contract: ethContract)
    }

    var success: Bool {
        status == "1" || message == "OK"
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
