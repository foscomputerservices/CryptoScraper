// RavencoinContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Ravencoin: an address, base58 of a 20-byte hash whose version is 60 (`R`) or 122 (`r`); kept as given
/// (base58 is case-sensitive)
public struct RavencoinContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Ravencoin's ladder: the chain's count to RVN, the base unit at exponent 0 and the chain's coin at 8
    public enum Units: String, CurrencyUnits {
        case base
        case rvn

        public static var chainBaseUnits: Self { .base }
        public static var defaultDisplayUnits: Self { .rvn }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = RavencoinChain

    /// The contract's address
    public let address: String

    /// Initializes the ``RavencoinContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension RavencoinContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension RavencoinContract {
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

public extension RavencoinContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for RVN
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "RVN" for the whole unit, "RVN(base)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .rvn
            ? "RVN"
            : "RVN(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in RVN
    var displayFractionDigits: Int { exponent }
}

private extension RavencoinContract.Units {
    var exponent: Int {
        switch self {
        case .base: return 0
        case .rvn: return 8
        }
    }
}

extension RavencoinContract {
    /// Whether `address` is base58 of a 20-byte hash whose version is 60 (`R`) or 122 (`r`)
    ///
    /// No checksum is verified.
    static func isWellFormed(_ address: String) -> Bool {
        BitcoinContract.base58AddressVersion(address).map { versions.contains($0) } == true
    }

    private static let versions: Set<Int> = [60, 122]
}
