// LitecoinContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Litecoin: an address, base58 of a 20-byte hash whose version is 48 (`L`), 50 (`M`) or 5 (`3`), or a
/// segregated-witness address, `ltc1` in lower case; kept as given (base58 is case-sensitive)
public struct LitecoinContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Litecoin's ladder: litoshi to LTC, the base unit at exponent 0 and the chain's coin at 8
    public enum Units: String, CurrencyUnits {
        case litoshi
        case ltc

        public static var chainBaseUnits: Self { .litoshi }
        public static var defaultDisplayUnits: Self { .ltc }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = LitecoinChain

    /// The contract's address
    public let address: String

    /// Initializes the ``LitecoinContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension LitecoinContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension LitecoinContract {
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

public extension LitecoinContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for LTC
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "LTC" for the whole unit, "LTC(litoshi)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .ltc
            ? "LTC"
            : "LTC(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in LTC
    var displayFractionDigits: Int { exponent }
}

private extension LitecoinContract.Units {
    var exponent: Int {
        switch self {
        case .litoshi: return 0
        case .ltc: return 8
        }
    }
}

extension LitecoinContract {
    /// Whether `address` is base58 of a 20-byte hash whose version is 48 (`L`), 50 (`M`) or 5 (`3`), or a
    /// segregated-witness address, `ltc1` in lower case
    ///
    /// No checksum is verified.
    static func isWellFormed(_ address: String) -> Bool {
        BitcoinContract.base58AddressVersion(address).map { versions.contains($0) } == true
            || BitcoinContract.isWitnessAddress(address, humanReadablePart: "ltc")
    }

    private static let versions: Set<Int> = [48, 50, 5]
}
