// DashContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Dash: an address, base58 of a 20-byte hash whose version is 76 (`X`) or 16 (`7`); kept as given
/// (base58 is case-sensitive)
public struct DashContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Dash's ladder: duffs to DASH, the base unit at exponent 0 and the chain's coin at 8
    public enum Units: String, CurrencyUnits {
        case duff
        case dash

        public static var chainBaseUnits: Self { .duff }
        public static var defaultDisplayUnits: Self { .dash }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = DashChain

    /// The contract's address
    public let address: String

    /// Initializes the ``DashContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension DashContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension DashContract {
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

public extension DashContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for DASH
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "DASH" for the whole unit, "DASH(duff)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .dash
            ? "DASH"
            : "DASH(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in DASH
    var displayFractionDigits: Int { exponent }
}

private extension DashContract.Units {
    var exponent: Int {
        switch self {
        case .duff: return 0
        case .dash: return 8
        }
    }
}

extension DashContract {
    /// Whether `address` is base58 of a 20-byte hash whose version is 76 (`X`) or 16 (`7`)
    ///
    /// No checksum is verified.
    static func isWellFormed(_ address: String) -> Bool {
        BitcoinContract.base58AddressVersion(address).map { versions.contains($0) } == true
    }

    private static let versions: Set<Int> = [76, 16]
}
