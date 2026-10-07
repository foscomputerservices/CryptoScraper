// DogecoinContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Dogecoin: an address, base58 of a 20-byte hash whose version is 30 (`D`) or 22 (`A` or `9`); kept as
/// given (base58 is case-sensitive)
public struct DogecoinContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Dogecoin's ladder: koinu to DOGE, the base unit at exponent 0 and the chain's coin at 8
    public enum Units: String, CurrencyUnits {
        case koinu
        case doge

        public static var chainBaseUnits: Self { .koinu }
        public static var defaultDisplayUnits: Self { .doge }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = DogecoinChain

    /// The contract's address
    public let address: String

    /// Initializes the ``DogecoinContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension DogecoinContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension DogecoinContract {
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

public extension DogecoinContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for DOGE
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "DOGE" for the whole unit, "DOGE(koinu)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .doge
            ? "DOGE"
            : "DOGE(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in DOGE
    var displayFractionDigits: Int { exponent }
}

private extension DogecoinContract.Units {
    var exponent: Int {
        switch self {
        case .koinu: return 0
        case .doge: return 8
        }
    }
}

extension DogecoinContract {
    /// Whether `address` is base58 of a 20-byte hash whose version is 30 (`D`) or 22 (`A` or `9`)
    ///
    /// No checksum is verified.
    static func isWellFormed(_ address: String) -> Bool {
        BitcoinContract.base58AddressVersion(address).map { versions.contains($0) } == true
    }

    private static let versions: Set<Int> = [30, 22]
}
