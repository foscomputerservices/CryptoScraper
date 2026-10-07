// FetchAIContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Fetch.ai: an account, bech32 `fetch1` and 38 characters (20 bytes) or 58 (32 bytes, a contract), in
/// lower case, or an IBC denom, `ibc/` and 64 upper-case hex digits; kept as given
public struct FetchAIContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Fetch.ai's ladder: afet to FET, the base unit at exponent 0 and the chain's coin at 18
    public enum Units: String, CurrencyUnits {
        case afet
        case fet

        public static var chainBaseUnits: Self { .afet }
        public static var defaultDisplayUnits: Self { .fet }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = FetchAIChain

    /// The contract's address
    public let address: String

    /// Initializes the ``FetchAIContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension FetchAIContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension FetchAIContract {
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

public extension FetchAIContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 18 for FET
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "FET" for the whole unit, "FET(afet)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .fet
            ? "FET"
            : "FET(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 18 digits in FET
    var displayFractionDigits: Int { exponent }
}

private extension FetchAIContract.Units {
    var exponent: Int {
        switch self {
        case .afet: return 0
        case .fet: return 18
        }
    }
}

extension FetchAIContract {
    /// Whether `address` is an account, bech32 `fetch1` and 38 characters (20 bytes) or 58 (32 bytes, a contract), in
    /// lower case, or an IBC denom, `ibc/` and 64 upper-case hex digits
    ///
    /// The bech32 checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        CosmosHubContract.isAccount(address, humanReadablePart: "fetch") || CosmosHubContract.isIBCDenom(address)
    }
}
