// MinaContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Mina: a public key, `B62` and 52 more characters of base58; kept as given (base58 is case-sensitive)
public struct MinaContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Mina's ladder: nanomina to MINA, the base unit at exponent 0 and the chain's coin at 9
    public enum Units: String, CurrencyUnits {
        case nanomina
        case mina

        public static var chainBaseUnits: Self { .nanomina }
        public static var defaultDisplayUnits: Self { .mina }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = MinaChain

    /// The contract's address
    public let address: String

    /// Initializes the ``MinaContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension MinaContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension MinaContract {
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

public extension MinaContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 9 for MINA
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "MINA" for the whole unit, "MINA(nanomina)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .mina
            ? "MINA"
            : "MINA(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 9 digits in MINA
    var displayFractionDigits: Int { exponent }
}

private extension MinaContract.Units {
    var exponent: Int {
        switch self {
        case .nanomina: return 0
        case .mina: return 9
        }
    }
}

extension MinaContract {
    /// Whether `address` is a public key, `B62` and 52 more characters of base58
    ///
    /// The key's checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        address.count == 55 && address.hasPrefix("B62") && address.allSatisfy { alphabet.contains($0) }
    }

    private static let alphabet = Set("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
}
