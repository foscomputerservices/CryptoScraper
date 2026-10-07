// VergeContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Verge: an address, base58 of a 20-byte hash whose version is 30 (`D`) or 33 (`E`), or a
/// segregated-witness address, `vg1` in lower case; kept as given (base58 is case-sensitive)
public struct VergeContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Verge's ladder: the chain's count to XVG, the base unit at exponent 0 and the chain's coin at 6
    public enum Units: String, CurrencyUnits {
        case base
        case xvg

        public static var chainBaseUnits: Self { .base }
        public static var defaultDisplayUnits: Self { .xvg }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = VergeChain

    /// The contract's address
    public let address: String

    /// Initializes the ``VergeContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension VergeContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension VergeContract {
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

public extension VergeContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 6 for XVG
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "XVG" for the whole unit, "XVG(base)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .xvg
            ? "XVG"
            : "XVG(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 6 digits in XVG
    var displayFractionDigits: Int { exponent }
}

private extension VergeContract.Units {
    var exponent: Int {
        switch self {
        case .base: return 0
        case .xvg: return 6
        }
    }
}

extension VergeContract {
    /// Whether `address` is base58 of a 20-byte hash whose version is 30 (`D`) or 33 (`E`), or a segregated-witness
    /// address, `vg1` in lower case
    ///
    /// No checksum is verified.
    static func isWellFormed(_ address: String) -> Bool {
        BitcoinContract.base58AddressVersion(address).map { versions.contains($0) } == true
            || BitcoinContract.isWitnessAddress(address, humanReadablePart: "vg")
    }

    private static let versions: Set<Int> = [30, 33]
}
