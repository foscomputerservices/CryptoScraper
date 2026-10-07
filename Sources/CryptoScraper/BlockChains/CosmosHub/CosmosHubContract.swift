// CosmosHubContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Cosmos Hub: an account, bech32 `cosmos1` and 38 characters (20 bytes) or 58 (32 bytes, a contract), in
/// lower case, or an IBC denom, `ibc/` and 64 upper-case hex digits; kept as given
public struct CosmosHubContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Cosmos Hub's ladder: uatom to ATOM, the base unit at exponent 0 and the chain's coin at 6
    public enum Units: String, CurrencyUnits {
        case uatom
        case atom

        public static var chainBaseUnits: Self { .uatom }
        public static var defaultDisplayUnits: Self { .atom }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = CosmosHubChain

    /// The contract's address
    public let address: String

    /// Initializes the ``CosmosHubContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension CosmosHubContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension CosmosHubContract {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.address = try container.decode(String.self, forKey: .address)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(address, forKey: .address)
    }

    private enum CodingKeys: String, CodingKey {
        case address
    }
}

public extension CosmosHubContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 6 for ATOM
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "ATOM" for the whole unit, "ATOM(uatom)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .atom
            ? "ATOM"
            : "ATOM(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 6 digits in ATOM
    var displayFractionDigits: Int { exponent }
}

private extension CosmosHubContract.Units {
    var exponent: Int {
        switch self {
        case .uatom: return 0
        case .atom: return 6
        }
    }
}

extension CosmosHubContract {
    /// Whether `address` is an account, bech32 `cosmos1` and 38 characters (20 bytes) or 58 (32 bytes, a contract), in
    /// lower case, or an IBC denom, `ibc/` and 64 upper-case hex digits
    ///
    /// The bech32 checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        CosmosHubContract.isAccount(address, humanReadablePart: "cosmos") || CosmosHubContract.isIBCDenom(address)
    }
}
