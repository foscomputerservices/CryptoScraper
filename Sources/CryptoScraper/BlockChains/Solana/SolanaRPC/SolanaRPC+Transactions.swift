// SolanaRPC+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension SolanaRPC {
    /// Retrieves the ``CryptoTransaction``s for the given account: its latest signatures, then each transaction, its
    /// SOL moved in or out of the account and its fee
    ///
    /// - Parameter account: The account from which to retrieve the transactions
    /// - Throws: ``SolanaRPCResponseError/requestFailed(_:)`` when the node answers any of its calls with an error or
    ///   no result
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let signatures: [SignatureResponse] = try await Self.call(
            "getSignaturesForAddress", [account.address, ["limit": 10]]
        )
        var result = [any CryptoTransaction]()
        for signature in signatures {
            let transaction: TransactionResponse = try await Self.call(
                "getTransaction", [signature.signature, ["encoding": "json", "maxSupportedTransactionVersion": 0]]
            )
            result += transaction.cryptoTransactions(signature: signature.signature, forAccount: account)
        }
        return result
    }

    /// Retrieves the ``CryptoTransaction``s of one `getTransaction` answer, the JSON-RPC envelope as the node sends
    /// it; each account whose SOL changed is a transaction
    /// - Throws: ``SolanaRPCResponseError/requestFailed(_:)`` when the envelope holds an error or no result
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: Response<TransactionResponse> = try data.fromJSON()
        let transaction = try response.value()
        return transaction.cryptoTransactions(signature: transaction.transaction.signatures.first ?? "", forAccount: nil)
    }
}

extension SolanaRPC {
    /// One row of `getSignaturesForAddress`'s result
    struct SignatureResponse: Decodable, Sendable {
        let signature: String
        let slot: UInt64
        let blockTime: Int64?
        let err: JSONNull?

        /// Whether the transaction failed: its `err` is not `null`
        var failed: Bool { err != nil }
    }

    /// Any JSON value but `null`, read only for whether it is there
    struct JSONNull: Decodable, Sendable {
        init(from decoder: any Decoder) throws {}
    }

    /// `getTransaction`'s result, `json` encoding: the account keys and each one's SOL before and after
    struct TransactionResponse: Decodable, Sendable {
        let slot: UInt64
        let blockTime: Int64?
        let meta: Meta
        let transaction: Transaction

        struct Meta: Decodable, Sendable {
            let err: JSONNull?
            let fee: UInt64
            let preBalances: [UInt64]
            let postBalances: [UInt64]
        }

        struct Transaction: Decodable, Sendable {
            let signatures: [String]
            let message: Message

            struct Message: Decodable, Sendable {
                let accountKeys: [String]
            }
        }

        /// One transaction per account whose SOL changed (only `account`'s when given): SOL moved in is from the fee
        /// payer, the first key, to the account; SOL moved out is from the account; the fee rides on the fee payer's
        func cryptoTransactions(signature: String, forAccount account: SolanaContract?) -> [any CryptoTransaction] {
            let keys = transaction.message.accountKeys
            let payer = keys.first.map { SolanaContract(address: $0) }
            var result = [any CryptoTransaction]()
            for index in keys.indices where index < meta.preBalances.count && index < meta.postBalances.count {
                let change = Int128(meta.postBalances[index]) - Int128(meta.preBalances[index])
                let holder = SolanaContract(address: keys[index])
                guard change != 0, account == nil || account == holder else { continue }
                let isPayer = index == 0
                result.append(MappedTransaction(
                    hash: signature,
                    fromContract: change > 0 ? payer : holder,
                    toContract: change > 0 ? holder : nil,
                    amount: .init(quantity: change < 0 ? -change : change, currency: SolanaChain.default.mainContract),
                    timeStamp: Date(timeIntervalSince1970: TimeInterval(blockTime ?? 0)),
                    transactionId: signature,
                    gasPrice: isPayer ? .init(quantity: Int128(meta.fee), currency: SolanaChain.default.mainContract) : nil,
                    successful: meta.err == nil
                ))
            }
            return result
        }
    }

    private struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = SolanaContract

        let hash: String
        let fromContract: SolanaContract?
        let toContract: SolanaContract?
        let amount: Amount<SolanaContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        let gasPrice: Amount<SolanaContract>?
        var gasUsed: Amount<SolanaContract>? { nil }
        let successful: Bool
        var functionName: String? { nil }
        var type: String? { "normal" }
    }
}
