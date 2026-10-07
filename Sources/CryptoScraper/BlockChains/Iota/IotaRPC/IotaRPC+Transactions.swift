// IotaRPC+Transactions.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension IotaRPC {
    /// Retrieves the ``CryptoTransaction``s for the given address: its latest transaction blocks sent from it and to
    /// it, newest first, each the IOTA the address gained or lost in it
    ///
    /// - Parameter account: The address from which to retrieve the transactions
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        var blocks: [TransactionBlocksResponse.Block] = []
        for filter in ["FromAddress", "ToAddress"] {
            let response: TransactionBlocksResponse = try await Self.call("iotax_queryTransactionBlocks", [
                ["filter": [filter: account.address], "options": Self.blockOptions] as [String: Any],
                NSNull(), 20, true
            ])
            blocks += response.data.filter { block in !blocks.contains { $0.digest == block.digest } }
        }
        blocks.sort { ($0.timestampMs ?? "") > ($1.timestampMs ?? "") }

        return try TransactionBlocksResponse(data: blocks).cryptoTransactions(forAccount: account)
    }

    /// Retrieves the ``CryptoTransaction``s of one `iotax_queryTransactionBlocks` answer, each block for its sender
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        guard !data.isEmpty else {
            return []
        }

        let response: Response<TransactionBlocksResponse> = try data.fromJSON()
        return try response.value().cryptoTransactions(forAccount: nil)
    }
}

extension IotaRPC {
    /// What each block is asked to carry: its sender, its effects and its balance changes
    static let blockOptions: [String: Bool] = ["showInput": true, "showEffects": true, "showBalanceChanges": true]

    /// `iotax_queryTransactionBlocks`'s result: `{ "data": [<block>], "nextCursor": …, "hasNextPage": … }`
    struct TransactionBlocksResponse: Decodable, Sendable {
        let data: [Block]

        struct Block: Decodable, Sendable {
            let digest: String
            let timestampMs: String?
            let transaction: Transaction?
            let effects: Effects?
            let balanceChanges: [BalanceChange]?

            struct Transaction: Decodable, Sendable {
                let data: TransactionData

                struct TransactionData: Decodable, Sendable {
                    let sender: String
                }
            }

            struct Effects: Decodable, Sendable {
                let status: Status
                let gasUsed: GasUsed

                struct Status: Decodable, Sendable {
                    let status: String
                }

                struct GasUsed: Decodable, Sendable {
                    let computationCost: String
                    let storageCost: String
                    let storageRebate: String
                }
            }

            struct BalanceChange: Decodable, Sendable {
                let owner: Owner
                let coinType: String
                let amount: String
            }

            /// A balance change's owner: an address (`{ "AddressOwner": "0x…" }`), or an object or a share, which is
            /// no address
            struct Owner: Decodable, Sendable {
                let address: String?

                init(from decoder: Decoder) throws {
                    let container = try? decoder.container(keyedBy: CodingKeys.self)
                    self.address = try container?.decodeIfPresent(String.self, forKey: .address)
                }

                private enum CodingKeys: String, CodingKey {
                    case address = "AddressOwner"
                }
            }
        }

        /// One transaction per block: the IOTA `account` gained or lost in it (its IOTA balance changes summed), from
        /// the sender to the account when it gained; with no account, the sender's own. The fee, its computation
        /// and storage less the rebate, is the sender's, in nanos; success is the status `success`.
        func cryptoTransactions(forAccount account: IotaContract?) throws -> [any CryptoTransaction] {
            let coin = IotaChain.default.mainContract!
            return try data.map { block in
                let sender = block.transaction.map { IotaContract.normalized($0.data.sender) }
                guard let holder = account?.address ?? sender else {
                    throw IotaRPCResponseError.requestFailed("block \(block.digest) names no sender")
                }
                var change = Int128(0)
                for row in block.balanceChanges ?? [] where row.coinType == IotaRPC.coinType {
                    guard let owner = row.owner.address, IotaContract.normalized(owner) == holder else { continue }
                    guard let amount = Int128(row.amount) else {
                        throw IotaRPCResponseError.requestFailed("amount \(row.amount) is not a count of nanos")
                    }
                    change += amount
                }
                let fee = block.effects.flatMap { effects -> Int128? in
                    guard
                        let computation = Int128(effects.gasUsed.computationCost),
                        let storage = Int128(effects.gasUsed.storageCost),
                        let rebate = Int128(effects.gasUsed.storageRebate)
                    else { return nil }
                    return computation + storage - rebate
                }
                return MappedTransaction(
                    hash: block.digest,
                    fromContract: IotaContract(address: change > 0 ? (sender ?? holder) : holder),
                    toContract: change > 0 ? IotaContract(address: holder) : nil,
                    amount: .init(quantity: change < 0 ? -change : change, currency: coin),
                    timeStamp: Date(timeIntervalSince1970: TimeInterval(Int64(block.timestampMs ?? "0") ?? 0) / 1000),
                    transactionId: block.digest,
                    gasPrice: fee.map { .init(quantity: $0, currency: coin) },
                    successful: block.effects?.status.status == "success",
                    type: nil
                )
            }
        }
    }
}
