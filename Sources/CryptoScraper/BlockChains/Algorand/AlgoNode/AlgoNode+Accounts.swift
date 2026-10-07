// AlgoNode+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension AlgoNode {
    /// Returns the balance, in microalgos, of the given account
    ///
    /// - Parameter account: The Algorand account to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: AccountResponse = try await Self.get(
            Self.endPoint.appending(path: "accounts").appending(path: account.address)
                .appending(queryItems: [.init(name: "exclude", value: "all")])
        )

        return response.amount()
    }

    /// Returns ALGO's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``AlgoNodeResponseError/unknownToken`` for any other contract: a standard asset's balance is not read
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw AlgoNodeResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }

    /// A standard asset's own statement of itself, its decimals among it: the oracle of an asset's decimals
    ///
    /// - Parameter contract: The asset, by its numeric id
    func getInfo(forToken contract: Contract) async throws -> SimpleTokenInfo<Contract> {
        let response: AssetResponse = try await Self.get(
            Self.endPoint.appending(path: "assets").appending(path: contract.address)
        )

        return response.tokenInfo(for: contract)
    }
}

extension AlgoNode {
    /// The node's `/v2/accounts/{address}`: `{ "address": …, "amount": <microalgos>, … }`
    struct AccountResponse: Decodable, Sendable {
        let address: String
        let microalgos: UInt64

        private enum CodingKeys: String, CodingKey {
            case address
            case microalgos = "amount"
        }

        /// The balance in ALGO's main contract, counted in microalgos
        func amount() -> Amount<AlgorandContract> {
            .init(quantity: Int128(microalgos), currency: AlgorandChain.default.mainContract)
        }
    }

    /// The node's `/v2/assets/{id}`: the asset's `params`, its `decimals`, `name` and `unit-name` among them
    struct AssetResponse: Decodable, Sendable {
        let index: UInt64
        let params: Params

        struct Params: Decodable, Sendable {
            let decimals: Int
            let name: String?
            let unitName: String?

            private enum CodingKeys: String, CodingKey {
                case decimals
                case name
                case unitName = "unit-name"
            }
        }

        /// The asset's token info, its decimals the chain's own
        func tokenInfo(for contract: AlgorandContract) -> SimpleTokenInfo<AlgorandContract> {
            .init(
                contractAddress: contract,
                equivalentContracts: [],
                tokenName: params.name ?? "",
                symbol: params.unitName ?? "",
                decimals: params.decimals
            )
        }
    }
}
