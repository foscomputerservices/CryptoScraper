// EnjinContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Enjin Relaychain: an account, SS58 of 32 bytes whose network prefix is 2135; kept as given (base58 is
/// case-sensitive)
public struct EnjinContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Enjin Relaychain's ladder: planck to ENJ, the base unit at exponent 0 and the chain's coin at 18
    public enum Units: String, CurrencyUnits {
        case planck
        case enj

        public static var chainBaseUnits: Self { .planck }
        public static var defaultDisplayUnits: Self { .enj }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = EnjinChain

    /// The contract's address
    public let address: String

    /// Initializes the ``EnjinContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension EnjinContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension EnjinContract {
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

public extension EnjinContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 18 for ENJ
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "ENJ" for the whole unit, "ENJ(planck)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .enj
            ? "ENJ"
            : "ENJ(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 18 digits in ENJ
    var displayFractionDigits: Int { exponent }
}

private extension EnjinContract.Units {
    var exponent: Int {
        switch self {
        case .planck: return 0
        case .enj: return 18
        }
    }
}

extension EnjinContract {
    /// Whether `address` is an account, SS58 of 32 bytes whose network prefix is 2135
    ///
    /// Read by shape; no checksum is verified unless this says so.
    static func isWellFormed(_ address: String) -> Bool {
        PolkadotContract.ss58Prefix(address) == 2135
    }

}
