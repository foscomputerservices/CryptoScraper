// TerraContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Terra: an account, bech32 `terra1` and 38 characters (20 bytes) or 58 (32 bytes, a contract), in lower
/// case, or an IBC denom, `ibc/` and 64 upper-case hex digits; kept as given
public struct TerraContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Terra's ladder: uluna to LUNA, the base unit at exponent 0 and the chain's coin at 6
    public enum Units: String, CurrencyUnits {
        case uluna
        case luna

        public static var chainBaseUnits: Self { .uluna }
        public static var defaultDisplayUnits: Self { .luna }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = TerraChain

    /// The contract's address
    public let address: String

    /// Initializes the ``TerraContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension TerraContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension TerraContract {
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

public extension TerraContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 6 for LUNA
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "LUNA" for the whole unit, "LUNA(uluna)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .luna
            ? "LUNA"
            : "LUNA(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 6 digits in LUNA
    var displayFractionDigits: Int { exponent }
}

private extension TerraContract.Units {
    var exponent: Int {
        switch self {
        case .uluna: return 0
        case .luna: return 6
        }
    }
}

extension TerraContract {
    /// Whether `address` is an account, bech32 `terra1` and 38 characters (20 bytes) or 58 (32 bytes, a contract), in
    /// lower case, or an IBC denom, `ibc/` and 64 upper-case hex digits
    ///
    /// The bech32 checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        CosmosHubContract.isAccount(address, humanReadablePart: "terra") || CosmosHubContract.isIBCDenom(address)
    }
}
