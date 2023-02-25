// BlockChainInfo+Transactions.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension BlockChainInfo {
    /// Retrieves the ``CryptoTransaction``s for the given contract
    ///
    /// - Parameter account: The contract from which to retrieve the transactions
    func getTransactions(forAccount account: CryptoContract) async throws -> [CryptoTransaction] {
        do {
            let response: SingleAddressResponse = try await Self.endPoint.appending(path: "rawaddr").appending(path: account.address).appending(
                queryItems: SingleAddressResponse.httpQuery(address: account)
            ).fetch(errorType: TransactionError.self)

            return try response.cryptoTransactions(forAccount: account)
        } catch let e as TransactionError {
            throw e.blockChainError
        }
    }
}

// {
//  "hash160": "660d4ef3a743e3e696ad990364e555c271ad504b",
//  "address": "1AJbsFZ64EpEfS5UAjAfcUG8pH8Jn3rn1F",
//  "n_tx": 17,
//  "n_unredeemed": 2,
//  "total_received": 1031350000,
//  "total_sent": 931250000,
//  "final_balance": 100100000,
//  "txs": [
//    "--Array of Transactions--"
//  ]
// }
private struct SingleAddressResponse: Decodable {
    let hash160: String
    let address: String
    let numberOfTransactions: UInt
    let numberUnredeemed: UInt
    let totalReceived: UInt64
    let totalSent: UInt64
    let finalBalance: UInt64
    let transactions: [Transaction]

    func cryptoTransactions(forAccount account: CryptoContract) throws -> [CryptoTransaction] {
        try transactions.flatMap { try $0.cryptoTransactions(forAccount: account) }
    }

    // https://www.blockchain.com/explorer/api/blockchain_api - Single Address
    static func httpQuery(address: CryptoContract, limit: UInt? = nil, offset: UInt? = nil) -> [URLQueryItem] {
        var result = [URLQueryItem]()

        if let limit {
            result.append(.init(name: "limit", value: "\(limit)"))
        }
        if let offset {
            result.append(.init(name: "offset", value: "\(offset)"))
        }

        return result
    }

    private enum CodingKeys: String, CodingKey {
        case hash160
        case address
        case numberOfTransactions = "n_tx"
        case numberUnredeemed = "n_unredeemed"
        case totalReceived = "total_received"
        case totalSent = "total_sent"
        case finalBalance = "final_balance"
        case transactions = "txs"
    }
}

// {
//  "hash": "b6f6991d03df0e2e04dafffcd6bc418aac66049e2cd74b80f14ac86db1e3f0da",
//  "ver": 1,
//  "vin_sz": 1,
//  "vout_sz": 2,
//  "lock_time": "Unavailable",
//  "size": 258,
//  "relayed_by": "64.179.201.80",
//  "block_height": 12200,
//  "tx_index": "12563028",
//  "inputs": [
//    {
//      "prev_out": {
//        "hash": "a3e2bcc9a5f776112497a32b05f4b9e5b2405ed9",
//        "value": "100000000",
//        "tx_index": "12554260",
//        "n": "2"
//      },
//      "script": "76a914641ad5051edd97029a003fe9efb29359fcee409d88ac"
//    }
//  ],
//  "out": [
//    {
//      "value": "98000000",
//      "hash": "29d6a3540acfa0a950bef2bfdc75cd51c24390fd",
//      "script": "76a914641ad5051edd97029a003fe9efb29359fcee409d88ac"
//    },
//    {
//      "value": "2000000",
//      "hash": "17b5038a413f5c5ee288caa64cfab35a0c01914e",
//      "script": "76a914641ad5051edd97029a003fe9efb29359fcee409d88ac"
//    }
//  ]
// }
private struct Transaction: Decodable {
    let hash: String
    let version: UInt
    let inSize: UInt
    let outSize: UInt
    let size: UInt
    let weight: UInt
    let fee: UInt64
    let relayedBy: String
    let lockTime: Int
    let transactionIndex: UInt64
    let doubleSpend: Bool
    let time: UInt
    let blockIndex: UInt64
    let blockHeight: UInt
    let inputs: [TxInput]
    let out: [TxOutput]
    let result: Int64
    let balance: UInt64

    func cryptoTransactions(forAccount account: CryptoContract) throws -> [CryptoTransaction] {
        var result = [CryptoTransaction]()

        // NOTE: We're mapping BTC transactions to an EVM-style contract standard as
        //   the EVM standard is more general.  Items don't map exactly one-to-one,
        //   but it should suffice to accomplish this library's goals.
        //
        //   We still have all of the data if we would like to do a BTC-specific API
        //   as well.  We'll see...

        // Find only the outgoing transactions, the other txns are back to us
        // https://www.bitcoin.com/get-started/how-bitcoin-transactions-work/
        for outTx in out.filter({ $0.address != account.address }) {
            result.append(try MappedTransaction(transaction: self, outTx: outTx, forAccount: account))
        }

        if fee > 0 {
            result.append(FeeTransaction(fee: fee, timeStamp: time, forAccount: account))
        }

        return result
    }

    private enum CodingKeys: String, CodingKey {
        case hash
        case version = "ver"
        case inSize = "vin_sz"
        case outSize = "vout_sz"
        case size
        case weight
        case fee
        case relayedBy = "relayed_by"
        case lockTime = "lock_time"
        case transactionIndex = "tx_index"
        case doubleSpend = "double_spend"
        case time
        case blockIndex = "block_index"
        case blockHeight = "block_height"
        case inputs
        case out
        case result
        case balance
    }

    private struct FeeTransaction: CryptoTransaction {
        let fromContract: CryptoContract?
        let toContract: CryptoContract? = nil
        let amount: CryptoAmount
        let timeStamp: Date
        let transactionId: String = ""
        let gas: Int? = nil
        let gasPrice: CryptoAmount?
        let gasUsed: CryptoAmount? = nil
        let successful: Bool = true

        init(fee: UInt64, timeStamp: UInt, forAccount account: CryptoContract) {
            self.fromContract = account
            self.amount = .init(quantity: 0, contract: BitcoinChain.bitcoin.mainContract)
            self.timeStamp = Date(timeIntervalSince1970: TimeInterval(timeStamp))
            self.gasPrice = .init(quantity: UInt128(fee), contract: BitcoinChain.bitcoin.mainContract)
        }
    }

    private struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        let fromContract: CryptoContract?
        let toContract: CryptoContract?
        let amount: CryptoAmount
        let timeStamp: Date
        let transactionId: String
        let gas: Int?
        var gasPrice: CryptoAmount?
        let gasUsed: CryptoAmount?
        let successful: Bool

        let methodId: String
        let functionName: String?

        init(transaction: Transaction, outTx: TxOutput, forAccount account: CryptoContract) throws {
            self.fromContract = account
            self.toContract = outTx.contract
            self.amount = outTx.amount
            self.timeStamp = Date(timeIntervalSince1970: TimeInterval(transaction.time))
            self.transactionId = transaction.hash
            self.gas = nil
            self.gasPrice = nil
            self.gasUsed = nil
            self.successful = true
            self.methodId = ""
            self.functionName = outTx.script
        }
    }
}

private struct TxInput: Decodable {
    let sequence: UInt64
    let witness: String
    let script: String
    let index: UInt64
    let prev_out: PreviousOut
}

private struct PreviousOut: Decodable {
    let address: String?
    let n: Int
    let script: String
    let spendingOutpoints: [SpendingOutpoint]
    let spent: Bool
    let transactionIndex: UInt64
    let type: Int
    let value: UInt64

    private enum CodingKeys: String, CodingKey {
        case address = "addr"
        case n
        case script
        case spendingOutpoints = "spending_outpoints"
        case spent
        case transactionIndex = "tx_index"
        case type
        case value
    }
}

private struct SpendingOutpoint: Decodable {
    let n: Int
    let tx_index: UInt64
}

private struct TxOutput: Decodable {
    let type: Int
    let spent: Bool
    let value: UInt64
    let spendingOutpoints: [SpendingOutpoint]
    let n: Int
    let transactionIndex: UInt64
    let script: String
    let address: String

    var contract: BitcoinContract? {
        .init(address: address)
    }

    var amount: CryptoAmount {
        .init(quantity: UInt128(value), contract: BitcoinChain.bitcoin.mainContract)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case spent
        case value
        case spendingOutpoints = "spending_outpoints"
        case n
        case transactionIndex = "tx_index"
        case script
        case address = "addr"
    }
}

private struct TransactionError: Error, Decodable {
    let error: String
    let message: String

    var localizedDescription: String {
        "\(error): \(message)"
    }

    var blockChainError: BlockChainInfoResponseError {
        .requestFailed(localizedDescription)
    }
}
