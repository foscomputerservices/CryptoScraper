// KusamaContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Kusama: an account, SS58 of 32 bytes whose network prefix is 2; kept as given (base58 is
/// case-sensitive)
public struct KusamaContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Kusama's ladder: planck to KSM, the base unit at exponent 0 and the chain's coin at 12
    public enum Units: String, CurrencyUnits {
        case planck
        case ksm

        public static var chainBaseUnits: Self { .planck }
        public static var defaultDisplayUnits: Self { .ksm }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = KusamaChain

    /// The contract's address
    public let address: String

    /// Initializes the ``KusamaContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension KusamaContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension KusamaContract {
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

public extension KusamaContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 12 for KSM
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "KSM" for the whole unit, "KSM(planck)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .ksm
            ? "KSM"
            : "KSM(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 12 digits in KSM
    var displayFractionDigits: Int { exponent }
}

private extension KusamaContract.Units {
    var exponent: Int {
        switch self {
        case .planck: return 0
        case .ksm: return 12
        }
    }
}

extension KusamaContract {
    /// Whether `address` is an account, SS58 of 32 bytes whose network prefix is 2, its prefix decoded
    ///
    /// The SS58 checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        PolkadotContract.ss58Prefix(address) == 2
    }
}
