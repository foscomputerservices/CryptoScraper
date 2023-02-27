// TronScan+Transactions.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension TronScan {
    /// Retrieves the ``CryptoTransaction``s for the given contract
    ///
    /// - Parameter account: The contract from which to retrieve the transactions
    func getTransactions(forAccount account: CryptoContract) async throws -> [CryptoTransaction] {
        let response: SingleAddressResponse = try await Self.endPoint.appending(path: "transaction").appending(
            queryItems: SingleAddressResponse.httpQuery(address: account)
        ).fetch()

        return try response.cryptoTransactions(forAccount: account)
    }
}

// {
//  "total": 9,
//  "rangeTotal": 9,
//  "data": [
//    ...
//  ],
//  "wholeChainTxCount": 4965462016,
//  "contractMap": {
//    "TUN4dKBLbAZjArUS7zYewHwCYA6GSUeSaK": false,
//    "TJWW1WGpTvMvXhAF2PBQd1GDkeWWdoxd2w": false,
//    "TELpgPLnuhNk5myFJDnKevsKXawWxKFMjL": false,
//    "TUuZrApYjwxoXBLNzccbqfBTNRnh9JYbdG": false,
//    "TJy5j5F1qGB3Pb2yrMb8As4SFZmj5oRZJd": false,
//    "TL4TMWyLzxmmmKiFr22euA1JhqibAqFgiG": false,
//    "TECYZ2opE2v7D5s2MhtuGuGfHWwSpVtzGj": false,
//    "TB9nJWnVCau6yvnjnR7DBDJ1xJvKxwqyUy": false,
//    "TG1hixs5nKKUzZUNAiMqgCo5EW5Mcm7mZm": false,
//    "TVj7RNVHy6thbM7BWdSe9G6gXwKhjhdNZS": true
//  },
//  "contractInfo": {
//    "TVj7RNVHy6thbM7BWdSe9G6gXwKhjhdNZS": {
//      "tag1": "KLV Token",
//      "tag1Url": "https://klever.io",
//      "name": "Klever",
//      "vip": false
//    }
//  }
// }
private struct SingleAddressResponse: Decodable {
    let data: [Transaction]

    func cryptoTransactions(forAccount account: CryptoContract) throws -> [CryptoTransaction] {
        try data.flatMap { try $0.cryptoTransactions(forAccount: account) }
    }

    // https://github.com/tronscan/tronscan-frontend/blob/dev2019/document/api.md#9
    static func httpQuery(address: CryptoContract, limit: UInt? = nil, offset: UInt? = nil) -> [URLQueryItem] {
        var result = [URLQueryItem]()

        result.append(.init(name: "address", value: address.address))
        result.append(.init(name: "sort", value: "-timestamp"))
        result.append(.init(name: "count", value: "true"))

        if let limit {
            result.append(.init(name: "limit", value: "\(limit)"))
        }

        if let offset {
            result.append(.init(name: "start", value: "\(offset)"))
        }

        return result
    }
}

//    {
//      "block": 47852838,
//      "hash": "9e718c06e164b60584f19718ee0aa0e885a3a1dc4a8abb6414db32a85a37d550",
//      "timestamp": 1674157230000,
//      "ownerAddress": "TJWW1WGpTvMvXhAF2PBQd1GDkeWWdoxd2w",
//      "toAddressList": [
//        "TVj7RNVHy6thbM7BWdSe9G6gXwKhjhdNZS"
//      ],
//      "toAddress": "TVj7RNVHy6thbM7BWdSe9G6gXwKhjhdNZS",
//      "contractType": 31,
//      "confirmed": true,
//      "revert": false,
//      "contractData": {
//        "data": "a9059cbb000000000000000000000041c2b305e8004b621da8ccefcc2d898d67fd3f38b000000000000000000000000000000000000000000000000000000001ef93d604",
//        "owner_address": "TJWW1WGpTvMvXhAF2PBQd1GDkeWWdoxd2w",
//        "contract_address": "TVj7RNVHy6thbM7BWdSe9G6gXwKhjhdNZS"
//      },
//      "SmartCalls": "",
//      "Events": "",
//      "id": "",
//      "data": "",
//      "fee": "",
//      "contractRet": "OUT_OF_ENERGY",
//      "result": "FAIL",
//      "amount": "0",
//      "cost": {
//        "net_fee": 0,
//        "energy_usage": 0,
//        "fee": 0,
//        "energy_fee": 0,
//        "energy_usage_total": 0,
//        "origin_energy_usage": 0,
//        "net_usage": 345
//      },

private struct Transaction: Decodable {
    let hash: String
    let timestamp: UInt
    let ownerAddress: String
    let toAddressList: [String]
    let toAddress: String
    let amount: String
    let confirmed: Bool
    let revert: Bool
    let fee: String
    let contractData: ContractData
    let tokenInfo: TokenInfo

    func cryptoTransactions(forAccount account: CryptoContract) throws -> [CryptoTransaction] {
        [TronTransaction(transaction: self)]
    }
}

private struct TronTransaction: CryptoTransaction {
    let fromContract: CryptoContract?
    let toContract: CryptoContract?
    let amount: CryptoAmount
    let timeStamp: Date
    let transactionId: String
    let gas: Int? = nil
    let gasPrice: CryptoAmount?
    let gasUsed: CryptoAmount? = nil
    let successful: Bool = true

    init(transaction: Transaction) {
        self.fromContract = TronContract(address: transaction.ownerAddress)
        self.toContract = TronContract(address: transaction.toAddress)
        self.amount = .init(quantity: UInt128(transaction.amount) ?? 0, contract: TronChain.default.mainContract)
        self.transactionId = transaction.hash
        self.timeStamp = Date(timeIntervalSince1970: TimeInterval(transaction.timestamp))
        self.gasPrice = .init(quantity: UInt128(transaction.fee) ?? 0, contract: TronChain.default.mainContract)
    }
}

// {
//    "amount": 60000000000,
//    "asset_name": "1004315",
//    "owner_address": "TJy5j5F1qGB3Pb2yrMb8As4SFZmj5oRZJd",
//    "to_address": "TJWW1WGpTvMvXhAF2PBQd1GDkeWWdoxd2w",
//    "tokenInfo": { ... }
// }
private struct ContractData: Decodable {
    let amount: UInt64?
    let assetName: String?
    let toAddress: String?
    let tokenInfo: TokenInfo?

    private enum CodingKeys: String, CodingKey {
        case amount
        case assetName = "asset_name"
        case toAddress = "to_address"
        case tokenInfo
    }
}

// {
//      "tokenId": "1004315",
//      "tokenAbbr": "Anime",
//      "tokenName": "Anime",
//      "tokenDecimal": 6,
//      "tokenCanShow": 1,
//      "tokenType": "trc10",
//      "tokenLogo": "https://static.tronscan.org/production/upload/logo/1004315.jpeg",
//      "tokenLevel": "0",
//      "vip": false
// }
private struct TokenInfo: Decodable {
    let tokenId: String
    let tokenAbbr: String
    let tokenDecimal: UInt
    let tokenCanShow: UInt
    let tokenType: String
    let tokenLogo: String
    let tokenLevel: String
    let vip: Bool
}
