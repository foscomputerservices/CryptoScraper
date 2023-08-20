// BitcoinExplorer+Accounts.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension BitcoinExplorer {
    /// Returns the balance (in BTC) of the given account
    ///
    /// - Parameter account: The Bitcoin account to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: BalanceResponse = try await Self.endPoint
            .appending(path: "address")
            .appending(path: account.address)
            .appending(queryItems: [
                .init(name: "sort", value: "asc")
            ])
            .fetch(errorType: BalanceError.self)

        return try response.amount
    }

    /// Returns balance of the given token for the given address
    ///
    /// - Parameters:
    ///   - contract: The contract of the token to query
    ///   - address: The contract address that holds the token
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        if contract.isChainToken {
            return try await getBalance(forAccount: account)
        } else {
            throw BitcoinExplorerResponseError.unknownToken
        }
    }
}

extension BitcoinExplorer {
    func getTransactionIds(forAccount account: Contract) async throws -> [String] {
        let response: BalanceResponse = try await Self.endPoint
            .appending(path: "address")
            .appending(path: account.address)
            .fetch(errorType: BalanceError.self)

        return response.transactionIds
    }
}

// https://bitcoinexplorer.org/api/docs
//    {
//      "base58": {
//        "hash": "22c17a06117b40516f9826804800003562e834c9",
//        "version": 5
//      },
//      "encoding": "base58",
//      "validateaddress": {
//        "isvalid": true,
//        "address": "34rng4QwB5pHUbGDJw1JxjLwgEU8TQuEqv",
//        "scriptPubKey": "a91422c17a06117b40516f9826804800003562e834c987",
//        "isscript": true,
//        "iswitness": false
//      },
//      "electrumScripthash": "124dbe6cf2394aa0e566d9b1df021343b563c694283038940e42ac9b24a50fcc",
//      "txHistory": {
//        "txCount": 2,
//        "txids": [
//          "5cf995061aeb00d36dd45b78514bdd4e091c299a0b1c10f030e4f56c200e3b1a",
//          "8f907925d2ebe48765103e6845c06f1f2bb77c6adc1cc002865865eb5cfd5c1c"
//        ],
//        "blockHeightsByTxid": {
//          "5cf995061aeb00d36dd45b78514bdd4e091c299a0b1c10f030e4f56c200e3b1a": 481830,
//          "8f907925d2ebe48765103e6845c06f1f2bb77c6adc1cc002865865eb5cfd5c1c": 481824
//        },
//        "balanceSat": 759000,
//        "request": {
//          "limit": 10,
//          "offset": 0,
//          "sort": "desc"
//        }
//      }
//    }
private struct BalanceResponse: Decodable {
    let transactionHistory: TransactionHistory

    struct TransactionHistory: Decodable {
        let transactionCount: Int
        let transactionIds: [String]
        let blockHeights: [String: UInt]
        let satoshiBalance: UInt64

        private enum CodingKeys: String, CodingKey {
            case transactionCount = "txCount"
            case transactionIds = "txids"
            case blockHeights = "blockHeightsByTxid"
            case satoshiBalance = "balanceSat"
        }
    }

    var amount: Amount<BitcoinChain.Contract> {
        get throws {
            let chain = BitcoinChain.default

            return .init(
                quantity: UInt128(transactionHistory.satoshiBalance),
                currency: chain.mainContract
            )
        }
    }

    var transactionIds: [String] {
        transactionHistory.transactionIds
    }

    private enum CodingKeys: String, CodingKey {
        case transactionHistory = "txHistory"
    }
}

private struct BalanceError: Error, Decodable {
    let success: Bool
    let error: String

    var localizedDescription: String {
        "Success - \(success): \(error)"
    }

    var blockChainError: BitcoinExplorerResponseError {
        .requestFailed(localizedDescription)
    }
}
