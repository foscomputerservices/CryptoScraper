// Dcrdata.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for dcrdata's public API, `dcrdata.decred.org`, keyless
///
/// Reads DCR: an address's unspent total (`/api/address/{address}/totals`), written in whole DCR. The raw
/// transactions read answered 422 when it was recorded, so ``getTransactions(forAccount:)`` throws.
public struct Dcrdata: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = DecredContract

    /// The Decred project's public dcrdata
    public static let endPoint: URL = .init(string: "https://dcrdata.decred.org/api")!

    /// "dcrdata"
    public let userReadableName: String = "dcrdata"

    public init() {}
}

public enum DcrdataResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    /// A token's balance is not read by this scanner
    case unknownToken

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown."
        case .unknownToken:
            return "Unable to read any balance on Decred but DCR's"
        }
    }
}

public extension Dcrdata {
    /// Returns the address's unspent DCR, in atoms
    ///
    /// - Parameter account: The Decred address to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: TotalsResponse = try await DataFetch<URLSession>.default.send(
            to: Self.endPoint.appending(path: "address").appending(path: account.address).appending(path: "totals"),
            httpMethod: "GET", headers: nil, locale: nil
        )

        return try response.amount()
    }

    /// Returns DCR's balance when `contract` is the chain's coin
    ///
    /// - Throws: ``DcrdataResponseError/unknownToken`` for any other contract
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        guard contract.isChainToken else {
            throw DcrdataResponseError.unknownToken
        }
        return try await getBalance(forAccount: account)
    }

    /// dcrdata's raw transactions read answered 422 when it was recorded (2026-10-07), so none are read
    ///
    /// - Throws: ``DcrdataResponseError/requestFailed(_:)``, always
    func getTransactions(forAccount account: Contract) async throws -> [any CryptoTransaction] {
        throw DcrdataResponseError.requestFailed(Self.noTransactions)
    }

    /// dcrdata's raw transactions read answered 422 when it was recorded, so no answer of it is read
    ///
    /// - Throws: ``DcrdataResponseError/requestFailed(_:)``, always
    func loadTransactions(from data: Data) throws -> [any CryptoTransaction] {
        throw DcrdataResponseError.requestFailed(Self.noTransactions)
    }
}

extension Dcrdata {
    static var noTransactions: String {
        "dcrdata's transactions are not read: its raw read answered 422 when recorded"
    }

    /// `/address/{address}/totals`: `{ "address", "num_stxos", "num_utxos", "dcr_spent", "dcr_unspent" }`, the amounts
    /// JSON numbers in whole DCR
    struct TotalsResponse: Decodable, Sendable {
        let dcrUnspent: Decimal

        private enum CodingKeys: String, CodingKey {
            case dcrUnspent = "dcr_unspent"
        }

        /// The unspent DCR in DCR's main contract, counted in atoms: the number as written, times 10^8, exactly
        func amount() throws -> Amount<DecredContract> {
            var atoms = dcrUnspent * 100_000_000
            var rounded = Decimal()
            NSDecimalRound(&rounded, &atoms, 0, .plain)
            guard rounded == atoms, let quantity = Int128(atoms.description) else {
                throw DcrdataResponseError.requestFailed("\(dcrUnspent) is not a whole count of atoms")
            }
            return .init(quantity: quantity, currency: DecredChain.default.mainContract)
        }
    }
}
