// EthereumScanner+Transactions.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension EthereumScanner {
    /// Retrieves the ``CryptoTransaction``s for the given contract
    ///
    /// - NOTE: This implementation includes ERC20 transactions as well as "normal" transactions.
    ///
    /// - Parameter account: The contract from which to retrieve the transactions
    func getTransactions(forAccount account: Contract) async throws -> [CryptoTransaction] {
        let response: TransactionResponse = try await Self.endPoint.appending(
            queryItems: TransactionResponse.httpQuery(address: account, apiKey: Self.requireApiKey())
        ).fetch()

        var result = [CryptoTransaction]()

        result += try response.cryptoTransactions(
            ethContract: account.chain.mainContract
        )

        result += try await getInternalTransactions(forAccount: account)

        if Self.supportedERCTokenTypes.contains(.erc20) {
            result += try await getERC20Transactions(
                forToken: nil, // All tokens
                forAccount: account
            )
        }

        return result
    }

    /// Retrieves the 'Internal' ``CryptoTransaction``s for the account
    ///
    /// - Parameter token: An optional token to filter the responses
    /// - Parameter account: The contract from which to retrieve the transactions
    func getInternalTransactions(forAccount account: Contract) async throws -> [CryptoTransaction] {
        let response: InternalTransactionResponse = try await Self.endPoint.appending(
            queryItems: InternalTransactionResponse.httpQuery(address: account, apiKey: Self.requireApiKey())
        ).fetch()

        return try response.cryptoTransactions(
            ethContract: account.chain.mainContract
        )
    }

    /// Retrieves the ERC20 token ``CryptoTransaction``s for the given token and account
    ///
    /// - Parameter token: An optional token to filter the responses
    /// - Parameter account: The contract from which to retrieve the transactions
    func getERC20Transactions(forToken token: Contract?, forAccount account: Contract) async throws -> [CryptoTransaction] {
        guard token?.isChainToken != true else { return [] }

        let response: ERC20TokenTransactionResponse = try await Self.endPoint.appending(
            queryItems: ERC20TokenTransactionResponse.httpQuery(address: account, token: token, apiKey: Self.requireApiKey())
        ).fetch()

        return try response.cryptoTransactions(
            ethContract: account.chain.mainContract
        )
    }

    /// Retrieves the ERC721 token ``CryptoTransaction``s for the given token and account
    ///
    /// - Parameter token: An optional token to filter the responses
    /// - Parameter account: The contract from which to retrieve the transactions
    func getERC721Transactions(forToken token: Contract?, forAccount account: Contract) async throws -> [CryptoTransaction] {
        guard token?.isChainToken != true else { return [] }

        let response: ERC721TokenTransactionResponse = try await Self.endPoint.appending(
            queryItems: ERC721TokenTransactionResponse.httpQuery(address: account, token: token, apiKey: Self.requireApiKey())
        ).fetch()

        return try response.cryptoTransactions(
            ethContract: account.chain.mainContract
        )
    }

    /// Retrieves the ERC1155 token ``CryptoTransaction``s for the given token and account
    ///
    /// - Parameter token: An optional token to filter the responses
    /// - Parameter account: The contract from which to retrieve the transactions
    func getERC1155Transactions(forToken token: Contract?, forAccount account: Contract) async throws -> [CryptoTransaction] {
        guard token?.isChainToken != true else { return [] }

        let response: ERC1155TokenTransactionResponse = try await Self.endPoint.appending(
            queryItems: ERC1155TokenTransactionResponse.httpQuery(address: account, token: token, apiKey: Self.requireApiKey())
        ).fetch()

        return try response.cryptoTransactions(
            ethContract: account.chain.mainContract
        )
    }

    /// Retrieves the ``CryptoTransaction`` entries from the provided ``Data``
    ///
    /// Ethereum provides for many different sources of transactions, each with their own
    /// format.  This implementation tries each format and returns an empty array if nothing
    /// matches.
    func loadTransactions(from data: Data) throws -> [CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        var result = [CryptoTransaction]()
        let mainContract = Contract(address: "dummy").chain.mainContract!

        // Try TransactionResponse
        do {
            let response: TransactionResponse = try data.fromJSON()

            result += try response.cryptoTransactions(
                ethContract: mainContract
            )
        } catch {}

        // Try InternalTransactionResponse
        do {
            let response: InternalTransactionResponse = try data.fromJSON()

            result += try response.cryptoTransactions(
                ethContract: mainContract
            )
        } catch {}

        // Try ERC20TokenTransactionResponse
        do {
            let response: ERC20TokenTransactionResponse = try data.fromJSON()

            result += try response.cryptoTransactions(
                ethContract: mainContract
            )
        } catch {}

        // Try ERC721TokenTransactionResponse
        do {
            let response: ERC721TokenTransactionResponse = try data.fromJSON()

            result += try response.cryptoTransactions(
                ethContract: mainContract
            )
        } catch {}

        // Try ERC1155TokenTransactionResponse
        do {
            let response: ERC721TokenTransactionResponse = try data.fromJSON()

            result += try response.cryptoTransactions(
                ethContract: mainContract
            )
        } catch {}

        return result
    }
}

// MARK: "Normal" Transaction

// https://docs.etherscan.io/api-endpoints/accounts#get-a-list-of-normal-transactions-by-address
private struct TransactionResponse: Decodable {
    private let status: String
    private let message: String
    private let result: [Transaction]

    var success: Bool {
        status == "1" || message == "OK"
    }

    func cryptoTransactions(ethContract: some CryptoContract) throws -> [CryptoTransaction] {
        guard success else {
            throw EthereumScannerResponseError.requestFailed(message)
        }

        return try result.map { try $0.cryptoTransaction(ethContract: ethContract) }
    }

    static func httpQuery(address: any CryptoContract, apiKey: String) -> [URLQueryItem] { [
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

        func cryptoTransaction(ethContract: some CryptoContract) throws -> CryptoTransaction {
            try MappedTransaction(transaction: self, ethContract: ethContract)
        }

        private struct MappedTransaction<Contract: CryptoContract>: EVMNormalTransaction {
            // MARK: CryptoTransaction

            let hash: String
            var fromContract: (any CryptoContract)? { _fromContract }
            var toContract: (any CryptoContract)? { _toContract }
            let amount: CryptoAmount
            let timeStamp: Date
            let transactionId: String
            let gas: Int?
            let gasPrice: CryptoAmount?
            let gasUsed: CryptoAmount?
            let successful: Bool

            let methodId: String
            let functionName: String?
            let input: String
            var type: String? { "normal" }

            private let _fromContract: Contract?
            private let _toContract: Contract?

            init(transaction: Transaction, ethContract: Contract) throws {
                self.hash = transaction.hash
                self._fromContract = transaction.from.isEmpty
                    ? nil
                    : Contract(address: transaction.from)
                self._toContract = transaction.to.isEmpty
                    ? nil
                    : Contract(address: transaction.to)

                let amount = UInt128(transaction.value)
                self.amount = amount == nil
                    ? .init(quantity: 0, contract: ethContract)
                    : .init(quantity: amount!, contract: ethContract)
                guard let timestamp = TimeInterval(transaction.timeStamp) else {
                    throw EthereumScannerResponseError.invalidData(
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
                    : CryptoAmount(quantity: gasPrice!, contract: ethContract)
                let gasUsed = UInt128(transaction.gasUsed)
                self.gasUsed = gasUsed == nil
                    ? nil
                    : CryptoAmount(quantity: gasUsed!, contract: ethContract)
                self.successful = transaction.isError == "0"
                self.methodId = transaction.methodId
                self.functionName = transaction.functionName.isEmpty
                    ? nil
                    : transaction.functionName
                self.input = transaction.input
            }
        }
    }
}

// MARK: "Internal" Transaction

// https://docs.etherscan.io/api-endpoints/accounts#get-a-list-of-internal-transactions-by-address
private struct InternalTransactionResponse: Decodable {
    private let status: String
    private let message: String
    private let result: [Transaction]

    var success: Bool {
        status == "1" || message == "OK"
    }

    func cryptoTransactions(ethContract: some CryptoContract) throws -> [CryptoTransaction] {
        guard success else {
            throw EthereumScannerResponseError.requestFailed(message)
        }

        return try result.map { try $0.cryptoTransaction(ethContract: ethContract) }
    }

    static func httpQuery(address: any CryptoContract, apiKey: String) -> [URLQueryItem] { [
        .init(name: "module", value: "account"),
        .init(name: "action", value: "txlistinternal"),
        .init(name: "address", value: address.address),
        .init(name: "startblock", value: "0"),
        .init(name: "endblock", value: "99999999"),
        .init(name: "page", value: "1"),
        .init(name: "offset", value: "0"),
        .init(name: "sort", value: "asc"),
        .init(name: "apiKey", value: apiKey)
    ] }

    private struct Transaction: Decodable {
        let blockNumber: String
        let timeStamp: String
        let hash: String
        let from: String
        let to: String
        let value: String
        let contractAddress: String
        let input: String
        let type: String
        let gas: String
        let gasUsed: String
        let traceId: String
        let isError: String
        let errCode: String

        func cryptoTransaction(ethContract: some CryptoContract) throws -> CryptoTransaction {
            try MappedTransaction(transaction: self, ethContract: ethContract)
        }

        private struct MappedTransaction<Contract: CryptoContract>: CryptoTransaction {
            // MARK: CryptoTransaction

            let hash: String
            var fromContract: (any CryptoContract)? { _fromContract }
            var toContract: (any CryptoContract)? { _toContract }
            let amount: CryptoAmount
            let timeStamp: Date
            let transactionId: String
            let gas: Int?
            let gasPrice: CryptoAmount?
            let gasUsed: CryptoAmount?
            let successful: Bool
            let functionName: String?
            var type: String? { "internal" }

            private let _fromContract: Contract?
            private let _toContract: Contract?

            init(transaction: Transaction, ethContract: Contract) throws {
                self.hash = transaction.hash
                self._fromContract = transaction.from.isEmpty
                    ? nil
                    : Contract(address: transaction.from)
                self._toContract = transaction.to.isEmpty
                    ? nil
                    : Contract(address: transaction.to)

                let amount = UInt128(transaction.value)
                self.amount = amount == nil
                    ? .init(quantity: 0, contract: ethContract)
                    : .init(quantity: amount!, contract: ethContract)
                guard let timestamp = TimeInterval(transaction.timeStamp) else {
                    throw EthereumScannerResponseError.invalidData(
                        type: "Transaction",
                        field: "timestamp",
                        value: transaction.timeStamp
                    )
                }
                self.timeStamp = Date(timeIntervalSince1970: timestamp)
                self.transactionId = transaction.hash
                self.gas = Int(transaction.gas)

                // TODO: Gas price comes from the base transaction
                let gasPrice = UInt128(0)
                self.gasPrice = CryptoAmount(quantity: gasPrice, contract: ethContract)
                let gasUsed = UInt128(transaction.gasUsed)
                self.gasUsed = gasUsed == nil
                    ? nil
                    : CryptoAmount(quantity: gasUsed!, contract: ethContract)
                self.successful = transaction.isError == "0"
                self.functionName = nil
            }
        }
    }
}

// MARK: ERC20 Token Transaction

// https://docs.etherscan.io/api-endpoints/accounts#get-a-list-of-erc20-token-transfer-events-by-address
private struct ERC20TokenTransactionResponse: Decodable {
    private let status: String
    private var message: String
    private let result: [ERC20TokenTransaction]

    var success: Bool {
        status == "1" || message == "OK" || message == "No transactions found"
    }

    func cryptoTransactions(ethContract: some CryptoContract) throws -> [CryptoTransaction] {
        guard success else {
            throw EthereumScannerResponseError.requestFailed(message)
        }

        return try result.map { try $0.cryptoTransaction(ethContract: ethContract) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.status = try container.decode(String.self, forKey: .status)
        self.message = try container.decode(String.self, forKey: .message)

        // Oye, they've already got status and message, but for rate limit
        // they throw a string into result 😡
        do {
            self.result = try container.decode([ERC20TokenTransaction].self, forKey: .result)
        } catch {
            let extraMessage = try container.decode(String.self, forKey: .result)

            guard extraMessage != "Max rate limit reached" else {
                throw EthereumScannerResponseError.rateLimitReached
            }

            self.result = []
            message += " -- \(extraMessage)"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case message
        case result
    }

    static func httpQuery(address: any CryptoContract, token: (any CryptoContract)?, apiKey: String) -> [URLQueryItem] {
        var result: [URLQueryItem] = [
            .init(name: "module", value: "account"),
            .init(name: "action", value: "tokentx"),
            .init(name: "address", value: address.address),
            .init(name: "startblock", value: "0"),
            .init(name: "endblock", value: "99999999"),
            .init(name: "page", value: "1"),
            .init(name: "offset", value: "0"),
            .init(name: "sort", value: "asc"),
            .init(name: "apiKey", value: apiKey)
        ]

        if let token {
            result.append(.init(name: "contractaddress", value: token.address))
        }

        return result
    }

    private struct ERC20TokenTransaction: Decodable {
        let blockNumber: String
        let timeStamp: String
        let hash: String
        let nonce: String
        let blockHash: String
        let from: String
        let contractAddress: String
        let to: String
        let value: String
        let tokenName: String
        let tokenSymbol: String
        let tokenDecimal: String
        let transactionIndex: String
        let gas: String
        let gasPrice: String
        let gasUsed: String
        let cumulativeGasUsed: String
        let input: String
        let confirmations: String

        func cryptoTransaction(ethContract: some CryptoContract) throws -> CryptoTransaction {
            try MappedTransaction(transaction: self, ethContract: ethContract)
        }

        // https://ethereum.org/en/developers/docs/standards/tokens/erc-20/
        private struct MappedTransaction<Contract: CryptoContract>: CryptoTransaction {
            // MARK: CryptoTransaction

            let hash: String
            var fromContract: (any CryptoContract)? { _fromContract }
            var toContract: (any CryptoContract)? { _toContract }
            let amount: CryptoAmount
            let timeStamp: Date
            let transactionId: String
            let gas: Int?
            let gasPrice: CryptoAmount?
            let gasUsed: CryptoAmount?
            let successful: Bool
            let functionName: String?
            var type: String? { "erc20" }

            private let _fromContract: Contract?
            private let _toContract: Contract?

            init(transaction: ERC20TokenTransaction, ethContract: Contract) throws {
                let tokenContract = Contract(address: transaction.contractAddress)

                self.hash = transaction.hash
                self._fromContract = transaction.from.isEmpty
                    ? nil
                    : Contract(address: transaction.from)
                self._toContract = transaction.to.isEmpty
                    ? nil
                    : Contract(address: transaction.to)

                let amount = UInt128(transaction.value)
                self.amount = amount == nil
                    ? .init(quantity: 0, contract: tokenContract)
                    : .init(quantity: amount!, contract: tokenContract)
                guard let timestamp = TimeInterval(transaction.timeStamp) else {
                    throw EthereumScannerResponseError.invalidData(
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
                    : CryptoAmount(quantity: gasPrice!, contract: ethContract)
                let gasUsed = UInt128(transaction.gasUsed)
                self.gasUsed = gasUsed == nil
                    ? nil
                    : CryptoAmount(quantity: gasUsed!, contract: ethContract)
                self.successful = true
                self.functionName = nil
            }
        }
    }
}

// MARK: ERC721 Token Transaction

// https://docs.etherscan.io/api-endpoints/accounts#get-a-list-of-erc721-token-transfer-events-by-address
private struct ERC721TokenTransactionResponse: Decodable {
    private let status: String
    private var message: String
    private let result: [ERC721TokenTransaction]

    var success: Bool {
        status == "1" || message == "OK" || message == "No transactions found"
    }

    func cryptoTransactions(ethContract: some CryptoContract) throws -> [CryptoTransaction] {
        guard success else {
            throw EthereumScannerResponseError.requestFailed(message)
        }

        return try result.map { try $0.cryptoTransaction(ethContract: ethContract) }
    }

    static func httpQuery(address: any CryptoContract, token: (any CryptoContract)?, apiKey: String) -> [URLQueryItem] {
        var result: [URLQueryItem] = [
            .init(name: "module", value: "account"),
            .init(name: "action", value: "tokennfttx"),
            .init(name: "address", value: address.address),
            .init(name: "startblock", value: "0"),
            .init(name: "endblock", value: "99999999"),
            .init(name: "page", value: "1"),
            .init(name: "offset", value: "0"),
            .init(name: "sort", value: "asc"),
            .init(name: "apiKey", value: apiKey)
        ]

        if let token {
            result.append(.init(name: "contractaddress", value: token.address))
        }

        return result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.status = try container.decode(String.self, forKey: .status)
        self.message = try container.decode(String.self, forKey: .message)

        // Oye, they've already got status and message, but for rate limit
        // they throw a string into result 😡
        do {
            self.result = try container.decode([ERC721TokenTransaction].self, forKey: .result)
        } catch {
            let extraMessage = try container.decode(String.self, forKey: .result)

            guard extraMessage != "Max rate limit reached" else {
                throw EthereumScannerResponseError.rateLimitReached
            }

            self.result = []
            message += " -- \(extraMessage)"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case message
        case result
    }

    private struct ERC721TokenTransaction: Decodable {
        let blockNumber: String
        let timeStamp: String
        let hash: String
        let nonce: String
        let blockHash: String
        let from: String
        let contractAddress: String
        let to: String
        let tokenID: String
        let tokenName: String
        let tokenSymbol: String
        let tokenDecimal: String
        let transactionIndex: String
        let gas: String
        let gasPrice: String
        let gasUsed: String
        let cumulativeGasUsed: String
        let input: String
        let confirmations: String

        func cryptoTransaction(ethContract: some CryptoContract) throws -> CryptoTransaction {
            try MappedTransaction(transaction: self, ethContract: ethContract)
        }

        // https://ethereum.org/en/developers/docs/standards/tokens/erc-721/ (NFT)
        private struct MappedTransaction<Contract: CryptoContract>: CryptoTransaction {
            // MARK: CryptoTransaction

            let hash: String
            var fromContract: (any CryptoContract)? { _fromContract }
            var toContract: (any CryptoContract)? { _toContract }
            let amount: CryptoAmount
            let timeStamp: Date
            let transactionId: String
            let gas: Int?
            let gasPrice: CryptoAmount?
            let gasUsed: CryptoAmount?
            let successful: Bool
            let functionName: String?
            var type: String? { "erc721" }

            private let _fromContract: Contract?
            private let _toContract: Contract?

            init(transaction: ERC721TokenTransaction, ethContract: Contract) throws {
                let tokenContract = Contract(address: transaction.contractAddress)

                self.hash = transaction.hash
                self._fromContract = transaction.from.isEmpty
                    ? nil
                    : Contract(address: transaction.from)
                self._toContract = transaction.to.isEmpty
                    ? nil
                    : Contract(address: transaction.to)

                // NFTs don't represent an amount
                self.amount = .init(quantity: 0, contract: tokenContract)
                guard let timestamp = TimeInterval(transaction.timeStamp) else {
                    throw EthereumScannerResponseError.invalidData(
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
                    : CryptoAmount(quantity: gasPrice!, contract: ethContract)
                let gasUsed = UInt128(transaction.gasUsed)
                self.gasUsed = gasUsed == nil
                    ? nil
                    : CryptoAmount(quantity: gasUsed!, contract: ethContract)
                self.successful = true
                self.functionName = nil
            }
        }
    }
}

// MARK: ERC1155 Token Transaction

// https://docs.etherscan.io/api-endpoints/accounts#get-a-list-of-erc1155-token-transfer-events-by-address
private struct ERC1155TokenTransactionResponse: Decodable {
    private let status: String
    private var message: String
    private let result: [ERC1155TokenTransaction]

    var success: Bool {
        status == "1" || message == "OK" || message == "No transactions found"
    }

    func cryptoTransactions(ethContract: some CryptoContract) throws -> [CryptoTransaction] {
        guard success else {
            throw EthereumScannerResponseError.requestFailed(message)
        }

        return try result.map { try $0.cryptoTransaction(ethContract: ethContract) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.status = try container.decode(String.self, forKey: .status)
        self.message = try container.decode(String.self, forKey: .message)

        // Oye, they've already got status and message, but for rate limit
        // they throw a string into result 😡
        do {
            self.result = try container.decode([ERC1155TokenTransaction].self, forKey: .result)
        } catch {
            let extraMessage = try container.decode(String.self, forKey: .result)

            guard extraMessage != "Max rate limit reached" else {
                throw EthereumScannerResponseError.rateLimitReached
            }

            self.result = []
            message += " -- \(extraMessage)"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case message
        case result
    }

    static func httpQuery(address: any CryptoContract, token: (any CryptoContract)?, apiKey: String) -> [URLQueryItem] {
        var result: [URLQueryItem] = [
            .init(name: "module", value: "account"),
            .init(name: "action", value: "token1155tx"),
            .init(name: "address", value: address.address),
            .init(name: "startblock", value: "0"),
            .init(name: "endblock", value: "99999999"),
            .init(name: "page", value: "1"),
            .init(name: "offset", value: "0"),
            .init(name: "sort", value: "asc"),
            .init(name: "apiKey", value: apiKey)
        ]

        if let token {
            result.append(.init(name: "contractaddress", value: token.address))
        }

        return result
    }

    private struct ERC1155TokenTransaction: Decodable {
        let blockNumber: String
        let timeStamp: String
        let hash: String
        let nonce: String
        let blockHash: String
        let transactionIndex: String
        let gas: String
        let gasPrice: String
        let gasUsed: String
        let cumulativeGasUsed: String
        let input: String
        let contractAddress: String
        let from: String
        let to: String
        let tokenID: String
        let tokenValue: String
        let tokenName: String
        let tokenSymbol: String
        let confirmations: String

        func cryptoTransaction(ethContract: some CryptoContract) throws -> CryptoTransaction {
            try MappedTransaction(transaction: self, ethContract: ethContract)
        }

        // https://eips.ethereum.org/EIPS/eip-1155
        private struct MappedTransaction<Contract: CryptoContract>: CryptoTransaction {
            // MARK: CryptoTransaction

            let hash: String
            var fromContract: (any CryptoContract)? { _fromContract }
            var toContract: (any CryptoContract)? { _toContract }
            let amount: CryptoAmount
            let timeStamp: Date
            let transactionId: String
            let gas: Int?
            let gasPrice: CryptoAmount?
            let gasUsed: CryptoAmount?
            let successful: Bool
            let functionName: String?
            var type: String? { "erc1155" }

            private let _fromContract: Contract?
            private let _toContract: Contract?

            init(transaction: ERC1155TokenTransaction, ethContract: Contract) throws {
                let tokenContract = Contract(address: transaction.contractAddress)

                self.hash = transaction.hash
                self._fromContract = transaction.from.isEmpty
                    ? nil
                    : Contract(address: transaction.from)
                self._toContract = transaction.to.isEmpty
                    ? nil
                    : Contract(address: transaction.to)

                let amount = UInt128(transaction.tokenValue)
                self.amount = amount == nil
                    ? .init(quantity: 0, contract: tokenContract)
                    : .init(quantity: amount!, contract: tokenContract)
                guard let timestamp = TimeInterval(transaction.timeStamp) else {
                    throw EthereumScannerResponseError.invalidData(
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
                    : CryptoAmount(quantity: gasPrice!, contract: ethContract)
                let gasUsed = UInt128(transaction.gasUsed)
                self.gasUsed = gasUsed == nil
                    ? nil
                    : CryptoAmount(quantity: gasUsed!, contract: ethContract)
                self.successful = true
                self.functionName = nil
            }
        }
    }
}
