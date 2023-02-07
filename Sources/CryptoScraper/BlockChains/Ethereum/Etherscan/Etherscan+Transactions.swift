// Etherscan+Transactions.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension Etherscan {
    /// Retrieves the ``CryptoTransaction``s for the given contract
    ///
    /// - Parameter account: The contract from which to retrieve the transactions
    func getTransactions(forAccount account: CryptoContract) async throws -> [CryptoTransaction] {
        let response: TransactionResponse = try await Self.endPoint.appending(
            queryItems: TransactionResponse.httpQuery(address: account, apiKey: Self.apiKey)
        ).fetch()

        return try response.cryptoTransactions(ethContract: account.chain.mainContract)
    }
}

private struct TransactionResponse: Decodable {
    let status: String
    let message: String
    let result: [Transaction]

    var success: Bool {
        status == "1" || message == "OK"
    }

    func cryptoTransactions(ethContract: CryptoContract) throws -> [CryptoTransaction] {
        guard success else {
            throw EtherscanResponseError.requestFailed("<Unknown Error>")
        }

        return try result.map { try $0.cryptoTransaction(ethContract: ethContract) }
    }

    // https://docs.etherscan.io/api-endpoints/accounts#get-a-list-of-normal-transactions-by-address
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

    func cryptoTransaction(ethContract: CryptoContract) throws -> CryptoTransaction {
        try MappedTransaction(transaction: self, ethContract: ethContract)
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

        init(transaction: Transaction, ethContract: CryptoContract) throws {
            self.fromContract = transaction.from.isEmpty
                ? nil
                : EthereumContract(address: transaction.from)
            self.toContract = transaction.to.isEmpty
                ? nil
                : EthereumContract(address: transaction.to)

            let amount = Int64(transaction.value)
            self.amount = amount == nil
                ? .init(quantity: 0, contract: ethContract)
                : .init(quantity: amount!, contract: ethContract)
            guard let timestamp = TimeInterval(transaction.timeStamp) else {
                throw EtherscanResponseError.invalidData(
                    type: "Transaction",
                    field: "timestamp",
                    value: transaction.timeStamp
                )
            }
            self.timeStamp = Date(timeIntervalSince1970: timestamp)
            self.transactionId = transaction.hash
            self.gas = Int(transaction.gas)

            let gasPrice = Int64(transaction.gasPrice)
            self.gasPrice = gasPrice == nil
                ? nil
                : CryptoAmount(quantity: gasPrice!, contract: ethContract)
            let gasUsed = Int64(transaction.gasUsed)
            self.gasUsed = gasUsed == nil
                ? nil
                : CryptoAmount(quantity: gasUsed!, contract: ethContract)
            self.successful = !(Bool(transaction.isError) ?? true /* default to isError == true */ )
            self.methodId = transaction.methodId
            self.functionName = transaction.functionName.isEmpty
                ? nil
                : transaction.functionName
        }
    }
}
