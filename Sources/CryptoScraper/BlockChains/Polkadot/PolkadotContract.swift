// PolkadotContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Polkadot: an account, SS58 of 32 bytes whose network prefix is 0; kept as given (base58 is
/// case-sensitive)
public struct PolkadotContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Polkadot's ladder: planck to DOT, the base unit at exponent 0 and the chain's coin at 10
    public enum Units: String, CurrencyUnits {
        case planck
        case dot

        public static var chainBaseUnits: Self { .planck }
        public static var defaultDisplayUnits: Self { .dot }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = PolkadotChain

    /// The contract's address
    public let address: String

    /// Initializes the ``PolkadotContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension PolkadotContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension PolkadotContract {
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

public extension PolkadotContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 10 for DOT
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "DOT" for the whole unit, "DOT(planck)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .dot
            ? "DOT"
            : "DOT(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 10 digits in DOT
    var displayFractionDigits: Int { exponent }
}

private extension PolkadotContract.Units {
    var exponent: Int {
        switch self {
        case .planck: return 0
        case .dot: return 10
        }
    }
}

extension PolkadotContract {
    /// Whether `address` is an account, SS58 of 32 bytes whose network prefix is 0, its prefix decoded
    ///
    /// The SS58 checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        PolkadotContract.ss58Prefix(address) == 0
    }
}
