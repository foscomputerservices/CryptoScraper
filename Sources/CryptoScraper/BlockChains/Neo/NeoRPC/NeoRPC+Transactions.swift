// NeoRPC+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension NeoRPC {
    /// Retrieves the ``CryptoTransaction``s for the given account: its NEP-17 transfers sent and received in the
    /// node's default window, NEO and GAS among them
    ///
    /// - Parameter account: The account from which to retrieve the transactions
    /// - Throws: ``NeoRPCResponseError/requestFailed(_:)`` when the node answers with an error or no result; a transfer
    ///   whose amount is not a count of base units is left out
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        let response: TransfersResponse = try await Self.call("getnep17transfers", [account.address])

        return response.cryptoTransactions()
    }

    /// Retrieves the ``CryptoTransaction``s of one `getnep17transfers` answer, the JSON-RPC envelope as the node
    /// sends it
    /// - Throws: ``NeoRPCResponseError/requestFailed(_:)`` when the envelope holds an error or no result
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: Response<TransfersResponse> = try data.fromJSON()
        return try response.value().cryptoTransactions()
    }
}

extension NeoRPC {
    /// `getnep17transfers`'s result: the account's transfers `sent` and `received`
    struct TransfersResponse: Decodable, Sendable {
        let address: String
        let sent: [Transfer]
        let received: [Transfer]

        struct Transfer: Decodable, Sendable {
            let timestamp: Int64
            let assethash: String
            let transferaddress: String?
            let amount: String
            let txhash: String
        }

        /// One transaction per transfer, in the contract its script hash names (NEO and GAS by their placeholders),
        /// counted in base units: sent from the account, received into it
        func cryptoTransactions() -> [any CryptoTransaction] {
            let account = NeoContract(address: address)
            let sentOnes = sent.map { ($0, true) }
            let receivedOnes = received.map { ($0, false) }
            return (sentOnes + receivedOnes).compactMap { transfer, isSent -> (any CryptoTransaction)? in
                guard let quantity = Int128(transfer.amount) else {
                    return nil
                }
                let other = transfer.transferaddress.map { NeoContract(address: $0) }
                return MappedTransaction(
                    hash: transfer.txhash,
                    fromContract: isSent ? account : other,
                    toContract: isSent ? other : account,
                    amount: .init(quantity: quantity, currency: NeoRPC.contract(ofScriptHash: transfer.assethash)),
                    timeStamp: Date(timeIntervalSince1970: TimeInterval(transfer.timestamp) / 1_000),
                    transactionId: transfer.txhash
                )
            }
        }
    }

    private struct MappedTransaction: CryptoTransaction {
        // MARK: CryptoTransaction

        typealias Contract = NeoContract

        let hash: String
        let fromContract: NeoContract?
        let toContract: NeoContract?
        let amount: Amount<NeoContract>
        let timeStamp: Date
        let transactionId: String
        var gas: Int? { nil }
        var gasPrice: Amount<NeoContract>? { nil }
        var gasUsed: Amount<NeoContract>? { nil }
        var successful: Bool { true }
        var functionName: String? { nil }
        var type: String? { "nep17" }
    }
}
