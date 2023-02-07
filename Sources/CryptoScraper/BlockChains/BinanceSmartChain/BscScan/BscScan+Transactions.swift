// BscScan+Transactions.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension BscScan {
    /// Retrieves the ``CryptoTransaction``s for the given contract
    ///
    /// - Parameter account: The contract from which to retrieve the transactions
    func getTransactions(forAccount account: CryptoContract) async throws -> [CryptoTransaction] {
        let response: TransactionResponse = try await Self.endPoint.appending(
            queryItems: TransactionResponse.httpQuery(address: account, apiKey: Self.apiKey)
        ).fetch()

        return try response.cryptoTransactions(bnbContract: account.chain.mainContract)
    }
}

private struct TransactionResponse: Decodable {
    let status: String
    let message: String
    let result: [Transaction]

    var success: Bool {
        status == "1" || message == "OK"
    }

    func cryptoTransactions(bnbContract: CryptoContract) throws -> [CryptoTransaction] {
        guard success else {
            throw BscScanResponseError.requestFailed("<Unknown Error>")
        }

        return try result.map { try $0.cryptoTransaction(bnbContract: bnbContract) }
    }

    // https://docs.bscscan.com/api-endpoints/accounts#get-a-list-of-normal-transactions-by-address
    static func httpQuery(address: CryptoContract, apiKey: String) -> [URLQueryItem] { [
        .init(name: "module", value: "account"),
        .init(name: "action", value: "txlist"),
        .init(name: "address", value: address.address),
        .init(name: "startblock", value: "0"),
        .init(name: "endblock", value: "99999999"),
        .init(name: "page", value: "1"),
        .init(name: "offset", value: "0"),
        .init(name: "sort", value: "asc"),
        .init(name: "apiKey", value: apiKey)
    ] }
}

private struct Transaction: Decodable {
    let blockNumber: String
    let timeStamp: String
    let hash: String
    let nonce: String
    let blockHash: String
    let transactionIndex: String
    let from: String
    let to: String
    let value: String
    let gas: String
    let gasPrice: String
    let isError: String
    let txreceipt_status: String
    let input: String
    let contractAddress: String
    let cumulativeGasUsed: String
    let gasUsed: String
    let confirmations: String
    let methodId: String
    let functionName: String

    func cryptoTransaction(bnbContract: CryptoContract) throws -> CryptoTransaction {
        try MappedTransaction(transaction: self, bnbContract: bnbContract)
    }

    private struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        let fromContract: CryptoContract?
        let toContract: CryptoContract?
        let amount: CryptoAmount
        let timeStamp: Date
        let transactionId: String
        let gas: Int?
        let gasPrice: CryptoAmount?
        let gasUsed: CryptoAmount?
        let successful: Bool

        let methodId: String
        let functionName: String?

        init(transaction: Transaction, bnbContract: CryptoContract) throws {
            self.fromContract = transaction.from.isEmpty
                ? nil
                : BNBContract(address: transaction.from)
            self.toContract = transaction.to.isEmpty
                ? nil
                : BNBContract(address: transaction.to)

            let amount = UInt128(transaction.value)
            self.amount = amount == nil
                ? .init(quantity: 0, contract: bnbContract)
                : .init(quantity: amount!, contract: bnbContract)
            guard let timestamp = TimeInterval(transaction.timeStamp) else {
                throw BscScanResponseError.invalidData(
                    type: "Transaction",
                    field: "timestamp",
                    value: transaction.timeStamp
                )
            }
            self.timeStamp = Date(timeIntervalSince1970: timestamp)
            self.transactionId = transaction.hash
            self.gas = Int(transaction.gas)

            let gasPrice = UInt128(transaction.gasPrice)
            self.gasPrice = gasPrice == nil
                ? nil
                : CryptoAmount(quantity: gasPrice!, contract: bnbContract)
            let gasUsed = UInt128(transaction.gasUsed)
            self.gasUsed = gasUsed == nil
                ? nil
                : CryptoAmount(quantity: gasUsed!, contract: bnbContract)
            self.successful = !(Bool(transaction.isError) ?? true /* default to isError == true */ )
            self.methodId = transaction.methodId
            self.functionName = transaction.functionName.isEmpty
                ? nil
                : transaction.functionName
        }
    }
}
