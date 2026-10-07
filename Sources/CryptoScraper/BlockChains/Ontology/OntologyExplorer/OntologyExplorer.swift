// OntologyExplorer.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for Ontology's public explorer API, `explorer.ont.io/v2`, keyless
///
/// Reads ONT and ONG: an address's native balances (`/v2/addresses/{address}/native/balances`), each written in whole
/// coins. The transactions read timed out when it was recorded, so ``getTransactions(forAccount:)`` throws; an OEP-4
/// token's balance is not read.
public struct OntologyExplorer: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = OntologyContract

    /// Ontology's public explorer API
    public static let endPoint: URL = .init(string: "https://explorer.ont.io/v2")!

    /// "Ontology Explorer"
    public let userReadableName: String = "Ontology Explorer"

    public init() {}
}

public enum OntologyExplorerResponseError: Error {
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
            return "Unable to read a token's balance on Ontology; only ONT's and ONG's are read"
        }
    }
}

extension OntologyExplorer {
    /// An amount as the explorer writes it, whole coins as a decimal string with at most `decimals` fraction digits,
    /// in the coin's base units; `nil` when it is not one
    static func baseUnits(_ text: String, decimals: Int) -> Int128? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), parts[0].allSatisfy(\.isASCII), let whole = Int128(parts[0]) else {
            return nil
        }
        let fraction = parts.count == 2 ? parts[1] : ""
        guard fraction.count <= decimals, fraction.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            return nil
        }
        let padded = fraction + String(repeating: "0", count: decimals - fraction.count)
        guard let fractionUnits = padded.isEmpty ? 0 : Int128(padded) else {
            return nil
        }
        return whole * (0..<decimals).reduce(Int128(1)) { power, _ in power * 10 } + fractionUnits
    }
}
