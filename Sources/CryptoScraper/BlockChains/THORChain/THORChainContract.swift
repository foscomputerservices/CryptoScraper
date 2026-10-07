// THORChainContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on THORChain: an account, bech32 `thor1` and 38 characters (20 bytes) or 58 (32 bytes, a contract), in
/// lower case, or an IBC denom, `ibc/` and 64 upper-case hex digits; kept as given
public struct THORChainContract: CryptoContract, Codable, Stubbable, Sendable {
    /// THORChain's ladder: the chain's count to RUNE, the base unit at exponent 0 and the chain's coin at 8
    public enum Units: String, CurrencyUnits {
        case base
        case rune

        public static var chainBaseUnits: Self { .base }
        public static var defaultDisplayUnits: Self { .rune }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = THORChainChain

    /// The contract's address
    public let address: String

    /// Initializes the ``THORChainContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension THORChainContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension THORChainContract {
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

public extension THORChainContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for RUNE
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "RUNE" for the whole unit, "RUNE(base)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .rune
            ? "RUNE"
            : "RUNE(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in RUNE
    var displayFractionDigits: Int { exponent }
}

private extension THORChainContract.Units {
    var exponent: Int {
        switch self {
        case .base: return 0
        case .rune: return 8
        }
    }
}

extension THORChainContract {
    /// Whether `address` is an account, bech32 `thor1` and 38 characters (20 bytes) or 58 (32 bytes, a contract), in
    /// lower case, or an IBC denom, `ibc/` and 64 upper-case hex digits
    ///
    /// The bech32 checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        CosmosHubContract.isAccount(address, humanReadablePart: "thor") || CosmosHubContract.isIBCDenom(address)
    }
}
