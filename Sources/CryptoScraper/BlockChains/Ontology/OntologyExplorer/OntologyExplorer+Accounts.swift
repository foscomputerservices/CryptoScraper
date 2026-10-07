// OntologyExplorer+Accounts.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension OntologyExplorer {
    /// Returns the address's ONT, the chain's coin, in its base units
    ///
    /// - Parameter account: The Ontology address to query the balance for
    /// - Throws: ``OntologyExplorerResponseError/requestFailed(_:)`` when the explorer answers a code other than 0 or
    ///   no result, or a balance that is not an amount at ONT's 9 decimals
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        try await getBalance(forToken: account.chain.mainContract, forAccount: account)
    }

    /// Returns the address's ONT or ONG, in their base units: the explorer states both in one answer
    ///
    /// - Throws: ``OntologyExplorerResponseError/unknownToken`` for any other contract: a token's balance is not read;
    ///   ``OntologyExplorerResponseError/requestFailed(_:)`` when the explorer answers a code other than 0 or no
    ///   result, or a balance that is not an amount at the coin's declared decimals (ONT 9, ONG 18)
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken || contract.address == OntologyChain.ongContractAddress else {
            throw OntologyExplorerResponseError.unknownToken
        }
        let response: BalancesResponse = try await DataFetch<URLSession>.default.send(
            to: Self.endPoint.appending(path: "addresses").appending(path: account.address).appending(path: "native")
                .appending(path: "balances"),
            httpMethod: "GET", headers: nil, locale: nil
        )

        return try response.amount(of: contract)
    }

    /// The explorer's transactions read timed out when it was recorded (2026-10-07), so none are read
    ///
    /// - Throws: ``OntologyExplorerResponseError/requestFailed(_:)``, always
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        throw OntologyExplorerResponseError.requestFailed(Self.noTransactions)
    }

    /// The explorer's transactions read timed out when it was recorded, so no answer of it is read
    ///
    /// - Throws: ``OntologyExplorerResponseError/requestFailed(_:)``, always
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        throw OntologyExplorerResponseError.requestFailed(Self.noTransactions)
    }
}

extension OntologyExplorer {
    static var noTransactions: String {
        "the Ontology explorer's transactions are not read: its read timed out when recorded"
    }

    /// `/v2/addresses/{address}/native/balances`: `{ "code": 0, "msg": "SUCCESS", "result": [{ "balance": "<whole
    /// coins>", "asset_name": "ont" | "ong" | …, "asset_type": "native", "contract_hash" }] }`
    struct BalancesResponse: Decodable, Sendable {
        let code: Int
        let msg: String
        let result: [Balance]?

        struct Balance: Decodable, Sendable {
            let balance: String
            let assetName: String

            private enum CodingKeys: String, CodingKey {
                case balance
                case assetName = "asset_name"
            }
        }

        /// The balance of `contract`, ONT or ONG, in its base units at its declared decimals (ONT 9, ONG 18); the
        /// row named `ont` or `ong`, never the unbound ONG
        func amount(of contract: OntologyContract) throws -> Amount<OntologyContract> {
            guard code == 0, let result else {
                throw OntologyExplorerResponseError.requestFailed("\(code) \(msg)")
            }
            let isONG = contract.address == OntologyChain.ongContractAddress
            let declared = isONG ? ONT.Ontology.ong : ONT.Ontology.ont
            let text = result.first { $0.assetName == (isONG ? "ong" : "ont") }?.balance ?? "0"
            guard let quantity = OntologyExplorer.baseUnits(text, decimals: declared.decimals) else {
                throw OntologyExplorerResponseError.requestFailed("\(text) is not an amount of \(declared.symbol.text)")
            }
            return .init(quantity: quantity, currency: contract)
        }
    }
}
