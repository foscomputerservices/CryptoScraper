// BitcoinExplorer+Transactions.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension BitcoinExplorer {
    /// Retrieves the ``CryptoTransaction``s for the given contract
    ///
    /// - Parameter account: The contract from which to retrieve the transactions
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        do {
            var result = [any CryptoTransaction]()

            for txnId in try await getTransactionIds(forAccount: account) {
                let response: Transaction = try await Self.endPoint
                    .appending(path: "tx")
                    .appending(path: txnId)
                    .fetch(errorType: TransactionError.self)

                try result.append(contentsOf: response.cryptoTransactions(forAccount: account))
            }

            return result
        } catch let e as TransactionError {
            throw e.blockChainError
        }
    }

    /// Retrieves the ``CryptoTransaction`` entries from the provided ``Data``
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        var result = [any CryptoTransaction]()
        let mainContract = BitcoinChain.default.mainContract!

        let response: Transaction = try data.fromJSON()

        result += try response.cryptoTransactions(
            forAccount: mainContract
        )

        return result
    }
}

//    {
//      "txid": "8e5e6b898750a7afbe683a953fbf30bd990bb57ccd2d904c76df29f61054e743",
//      "hash": "8e5e6b898750a7afbe683a953fbf30bd990bb57ccd2d904c76df29f61054e743",
//      "version": 1,
//      "size": 521,
//      "vsize": 521,
//      "weight": 2084,
//      "locktime": 0,
//      "vin": [
//        {
//          "txid": "d482ceff793a908c3bd574a4f41f392c80bccc127530209f09c12b97f226bf2b",
//          "vout": 0,
//          "scriptSig": {
//            "asm": "3045022100d990e9b0d35a76da1c5e2d719d20fa2504897f7eec12b630cc08751bb220560b022070d36f144d17ef8cc3ff3262a419122fc6964725df6095826cdd77a93a0334a3[ALL] 035ed20ff573ca7c0a406307de0fb47dfc62361a873162cbe71fe6712b101942d2",
//            "hex": "483045022100d990e9b0d35a76da1c5e2d719d20fa2504897f7eec12b630cc08751bb220560b022070d36f144d17ef8cc3ff3262a419122fc6964725df6095826cdd77a93a0334a30121035ed20ff573ca7c0a406307de0fb47dfc62361a873162cbe71fe6712b101942d2",
//            "address": "1PAiaQe6KEaEtCQEpLLnLF57QyiuCp42H8",
//            "type": "pubkeyhash"
//          },
//          "sequence": 4294967295,
//          "value": 0.00752664
//        },
//        {
//          "txid": "3c4967627b014de6130a106c4754c567f1f62619690a9910ee479e3f7ee125da",
//          "vout": 0,
//          "scriptSig": {
//            "asm": "3045022100b9b72e676237bc72c2a66b2739653b1b1397689180432912ed715e1d60d2ab8a022040bee911cab89b51de76bffe99b5051fa46eae5a38fc7099303576793f98293e[ALL] 035ed20ff573ca7c0a406307de0fb47dfc62361a873162cbe71fe6712b101942d2",
//            "hex": "483045022100b9b72e676237bc72c2a66b2739653b1b1397689180432912ed715e1d60d2ab8a022040bee911cab89b51de76bffe99b5051fa46eae5a38fc7099303576793f98293e0121035ed20ff573ca7c0a406307de0fb47dfc62361a873162cbe71fe6712b101942d2",
//            "address": "1PAiaQe6KEaEtCQEpLLnLF57QyiuCp42H8",
//            "type": "pubkeyhash"
//          },
//          "sequence": 4294967295,
//          "value": 0.00832293
//        },
//        {
//          "txid": "625e98915b0524cede24194cc2c89e3a18e923be2798206d81fe34471a2be938",
//          "vout": 59,
//          "scriptSig": {
//            "asm": "3044022006134a29f0eb64a0e5476778b7862143abcb814aa62224a53a969594ec99d98402206db0126fcb3e13eb1d65126eff5f4ad162499d62b28e5134d8165f2bbdb3316a[ALL] 035ed20ff573ca7c0a406307de0fb47dfc62361a873162cbe71fe6712b101942d2",
//            "hex": "473044022006134a29f0eb64a0e5476778b7862143abcb814aa62224a53a969594ec99d98402206db0126fcb3e13eb1d65126eff5f4ad162499d62b28e5134d8165f2bbdb3316a0121035ed20ff573ca7c0a406307de0fb47dfc62361a873162cbe71fe6712b101942d2",
//            "address": "1PAiaQe6KEaEtCQEpLLnLF57QyiuCp42H8",
//            "type": "pubkeyhash"
//          },
//          "sequence": 4294967295,
//          "value": 0.00879576
//        }
//      ],
//      "vout": [
//        {
//          "value": 0.02413,
//          "n": 0,
//          "scriptPubKey": {
//            "asm": "OP_DUP OP_HASH160 660d4ef3a743e3e696ad990364e555c271ad504b OP_EQUALVERIFY OP_CHECKSIG",
//            "desc": "addr(1AJbsFZ64EpEfS5UAjAfcUG8pH8Jn3rn1F)#yd84ssy7",
//            "hex": "76a914660d4ef3a743e3e696ad990364e555c271ad504b88ac",
//            "address": "1AJbsFZ64EpEfS5UAjAfcUG8pH8Jn3rn1F",
//            "type": "pubkeyhash"
//          }
//        },
//        {
//          "value": 0.00002465,
//          "n": 1,
//          "scriptPubKey": {
//            "asm": "OP_DUP OP_HASH160 f329377f8f4c6f9e4a532bfb99b06d110d5277ab OP_EQUALVERIFY OP_CHECKSIG",
//            "desc": "addr(1PAiaQe6KEaEtCQEpLLnLF57QyiuCp42H8)#nef9lhau",
//            "hex": "76a914f329377f8f4c6f9e4a532bfb99b06d110d5277ab88ac",
//            "address": "1PAiaQe6KEaEtCQEpLLnLF57QyiuCp42H8",
//            "type": "pubkeyhash"
//          }
//        }
//      ],
//      "hex": "01000000032bbf26f2972bc1099f20307512ccbc802c391ff4a474d53b8c903a79ffce82d4000000006b483045022100d990e9b0d35a76da1c5e2d719d20fa2504897f7eec12b630cc08751bb220560b022070d36f144d17ef8cc3ff3262a419122fc6964725df6095826cdd77a93a0334a30121035ed20ff573ca7c0a406307de0fb47dfc62361a873162cbe71fe6712b101942d2ffffffffda25e17e3f9e47ee10990a691926f6f167c554476c100a13e64d017b6267493c000000006b483045022100b9b72e676237bc72c2a66b2739653b1b1397689180432912ed715e1d60d2ab8a022040bee911cab89b51de76bffe99b5051fa46eae5a38fc7099303576793f98293e0121035ed20ff573ca7c0a406307de0fb47dfc62361a873162cbe71fe6712b101942d2ffffffff38e92b1a4734fe816d209827be23e9183a9ec8c24c1924dece24055b91985e623b0000006a473044022006134a29f0eb64a0e5476778b7862143abcb814aa62224a53a969594ec99d98402206db0126fcb3e13eb1d65126eff5f4ad162499d62b28e5134d8165f2bbdb3316a0121035ed20ff573ca7c0a406307de0fb47dfc62361a873162cbe71fe6712b101942d2ffffffff02c8d12400000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88aca1090000000000001976a914f329377f8f4c6f9e4a532bfb99b06d110d5277ab88ac00000000",
//      "blockhash": "0000000000000000000c6339021601f591f80e35b649e0b8990cdd929f99203b",
//      "confirmations": 144680,
//      "time": 1597425899,
//      "blocktime": 1597425899,
//      "fee": {
//        "amount": 0.00049068,
//        "unit": "BTC"
//      }
//    }
private struct Transaction: Decodable {
    let transactionId: String
    let hash: String
    let version: UInt
    let valuesIn: [ValueIn]
    let valuesOut: [ValueOut]
    let timestamp: UInt
    let fee: Fee

    func cryptoTransactions(forAccount account: BitcoinContract) throws -> [any CryptoTransaction] {
        var result: [any CryptoTransaction] = try valuesOut
            .filter { $0.contract.address == account.address }
            .map { valueOut in
                try MappedTransaction(
                    transaction: self,
                    outTx: valueOut,
                    forAccount: account
                )
            }

        if fee.amount > 0 {
            result.append(
                FeeTransaction(
                    hash: hash,
                    fee: fee.amount,
                    timeStamp: timestamp,
                    forAccount: account
                )
            )
        }

        return result
    }

    private enum CodingKeys: String, CodingKey {
        case transactionId = "txid"
        case hash
        case version
        case valuesIn = "vin"
        case valuesOut = "vout"
        case timestamp = "time"
        case fee
    }
}

private struct MappedTransaction: CryptoTransaction {
    typealias Chain = BitcoinChain

    // MARK: CryptoTransaction

    let hash: String
    var fromContract: Chain.Contract? { _fromContract }
    var toContract: Chain.Contract? { _toContract }
    let amount: Amount<Chain.Contract>
    let timeStamp: Date
    let transactionId: String
    let gas: Int?
    var gasPrice: Amount<Chain.Contract>?
    let gasUsed: Amount<Chain.Contract>?
    let successful: Bool

    let methodId: String
    let functionName: String?
    var type: String? { "normal" }

    private let _fromContract: Chain.Contract
    private let _toContract: Chain.Contract?

    init(transaction: Transaction, outTx: ValueOut, forAccount account: Chain.Contract) throws {
        self.hash = transaction.hash
        self._fromContract = account
        self._toContract = outTx.contract
        self.amount = outTx.amount
        self.timeStamp = Date(timeIntervalSince1970: TimeInterval(transaction.timestamp))
        self.transactionId = transaction.hash
        self.gas = nil
        self.gasPrice = nil
        self.gasUsed = nil
        self.successful = true
        self.methodId = ""
        self.functionName = "" // outTx.script
    }
}

private struct ValueIn: Decodable {
    let transactionId: String
    let valueOut: Double // Values are in BTC! Ugh!!
    let value: Double // Values are in BTC! Ugh!!

    private enum CodingKeys: String, CodingKey {
        case transactionId = "txid"
        case valueOut = "vout"
        case value
    }
}

private struct ValueOut: Decodable {
    let value: Double // Values are in BTC! Ugh!!
    let index: UInt
    let scriptPubKey: ScriptPubKey

    var contract: BitcoinContract {
        let address: String

        switch scriptPubKey.type {
        case .pubKeyHash: address = scriptPubKey.address!
        case .pubKey: address = scriptPubKey.hex!
        }

        return .init(address: address)
    }

    var amount: Amount<BitcoinChain.Contract> {
        let sats = UInt(value * 8.0)
        return .init(quantity: UInt128(sats), currency: BitcoinChain.default.mainContract!)
    }

    struct ScriptPubKey: Decodable {
        let address: String? // Address when type == pubKeyHash
        let hex: String? // PublicKey address for type == pubKey
        let type: AddressType

        enum AddressType: String, Codable {
            case pubKeyHash = "pubkeyhash"
            case pubKey = "pubkey"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case index = "n"
        case scriptPubKey
    }
}

private struct Fee: Decodable {
    private let btcAmount: Double // Values are in BTC! Ugh!!
    var amount: UInt64 {
        UInt64(btcAmount * 8.0)
    }

    let unit: String

    private enum CodingKeys: String, CodingKey {
        case btcAmount = "amount"
        case unit
    }
}

private struct FeeTransaction: CryptoTransaction {
    typealias Chain = BitcoinChain

    let hash: String
    var fromContract: Chain.Contract? { _fromContract }
    var toContract: Chain.Contract? { nil }
    let amount: Amount<Chain.Contract>
    let timeStamp: Date
    var transactionId: String { "" }
    var gas: Int? { nil }
    let gasPrice: Amount<Chain.Contract>?
    var gasUsed: Amount<Chain.Contract>? { nil }
    var successful: Bool { true }
    var functionName: String? { nil }
    var type: String? { "fee" }

    private let _fromContract: Chain.Contract

    init(hash: String, fee: UInt64, timeStamp: UInt, forAccount account: BitcoinContract) {
        self.hash = hash
        self._fromContract = account
        self.amount = .init(quantity: 0, currency: BitcoinChain.bitcoin.mainContract)
        self.timeStamp = Date(timeIntervalSince1970: TimeInterval(timeStamp))
        self.gasPrice = .init(quantity: UInt128(fee), currency: BitcoinChain.bitcoin.mainContract)
    }
}

private struct TransactionError: Error, Decodable {
    let success: Bool
    let error: String

    var localizedDescription: String {
        "Success - \(success): \(error)"
    }

    var blockChainError: BitcoinExplorerResponseError {
        .requestFailed(localizedDescription)
    }
}
