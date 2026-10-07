// EthereumScanner+Accounts.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension EthereumScanner {
    /// Returns the balance of the given account in the chain's coin, counted in its base unit (wei on Ethereum)
    ///
    /// - Parameter account: The account to query the balance for
    ///
    /// - Throws: ``EthereumScannerResponseError/missingApiKey(_:)`` until the key is set,
    ///   ``EthereumScannerResponseError/requestFailed(_:)`` when V2 refuses, and
    ///   ``EthereumScannerResponseError/invalidAmount`` when the answer is not an integer
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: AccountResponse = try await Self.requestURL(AccountResponse.httpQuery(account: account)).fetch()

        return try response.amount(
            forAccount: account.chain.mainContract
        )
    }
}

struct AccountResponse: Decodable {
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

        guard let amount = Int128(result) else {
            throw EthereumScannerResponseError.invalidAmount
        }

        return .init(quantity: amount, currency: ethContract)
    }

    // https://docs.etherscan.io/api-endpoints/accounts#get-ether-balance-for-a-single-address
    static func httpQuery(account: any CryptoContract) -> [URLQueryItem] { [
        .init(name: "module", value: "account"),
        .init(name: "action", value: "balance"),
        .init(name: "address", value: account.address),
        .init(name: "tag", value: "latest")
    ] }
}
