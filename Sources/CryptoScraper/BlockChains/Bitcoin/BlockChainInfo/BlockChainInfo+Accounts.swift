// BlockChainInfo+Accounts.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension BlockChainInfo {
    /// Returns the balance (in BTC) of the given account
    ///
    /// - Parameter account: The Bitcoin account to query the balance for
    func getBalance(forAccount account: Contract) async throws -> CryptoAmount {
        let response: BalanceResponse = try await Self.endPoint.appending(path: "balance").appending(
            queryItems: BalanceResponse.httpQuery(account: account)
        ).fetch(errorType: BalanceError.self)

        return try response.cryptoAmount(forAccount: account)
    }

    /// Returns balance of the given token for the given address
    ///
    /// - Parameters:
    ///   - contract: The contract of the token to query
    ///   - address: The contract address that holds the token
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> CryptoAmount {
        // Cannot retrieve ETH contract, but retrieve ETH balance
        if contract.isChainToken {
            return try await getBalance(forAccount: account)
        } else {
            throw BlockChainInfoResponseError.unknownToken
        }
    }
}

// {
//  "1MDUoxL1bGvMxhuoDYx6i11ePytECAk9QK": {
//    "final_balance": 0,
//    "n_tx": 0,
//    "total_received": 0
//  },
//  "15EW3AMRm2yP6LEF5YKKLYwvphy3DmMqN6": {
//    "final_balance": 0,
//    "n_tx": 2,
//    "total_received": 310630609
//  }
// }
private struct BalanceResponse: Decodable {
    private let responses: [String: Response]

    var success: Bool {
        !responses.isEmpty
    }

    func cryptoAmount(forAccount btcContract: any CryptoContract) throws -> CryptoAmount {
        guard success, let response = responses.first(where: { $0.key == btcContract.address })?.value else {
            throw BlockChainInfoResponseError.unknownContract(btcContract.address)
        }

        let chain = btcContract.chain as (any CryptoChain)

        return .init(
            quantity: UInt128(response.finalBalance),
            contract: chain.mainContract as (any CryptoContract)
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        self.responses = try container.decode([String: Response].self)
    }

    // https://www.blockchain.com/explorer/api/blockchain_api - Balance
    static func httpQuery(account: any CryptoContract) -> [URLQueryItem] { [
        .init(name: "active", value: account.address)
    ] }

    private struct Response: Decodable {
        let finalBalance: UInt64
        let numberOfTransactions: Int
        let totalReceived: UInt64

        private enum CodingKeys: String, CodingKey {
            case finalBalance = "final_balance"
            case numberOfTransactions = "n_tx"
            case totalReceived = "total_received"
        }
    }
}

private struct BalanceError: Error, Decodable {
    let error: String
    let message: String

    var localizedDescription: String {
        "\(error): \(message)"
    }

    var blockChainError: BlockChainInfoResponseError {
        .requestFailed(localizedDescription)
    }
}
