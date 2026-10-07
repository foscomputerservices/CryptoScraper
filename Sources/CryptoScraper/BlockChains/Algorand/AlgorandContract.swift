// AlgorandContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Algorand: an account, 58 characters of upper-case base32, or a standard asset (ASA) by its numeric id;
/// kept as given
public struct AlgorandContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Algorand's ladder: microalgos to ALGO, the base unit at exponent 0 and the chain's coin at 6
    public enum Units: String, CurrencyUnits {
        case microalgo
        case algo

        public static var chainBaseUnits: Self { .microalgo }
        public static var defaultDisplayUnits: Self { .algo }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = AlgorandChain

    /// The contract's address
    public let address: String

    /// Initializes the ``AlgorandContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension AlgorandContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension AlgorandContract {
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

public extension AlgorandContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 6 for ALGO
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "ALGO" for the whole unit, "ALGO(microalgo)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .algo
            ? "ALGO"
            : "ALGO(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 6 digits in ALGO
    var displayFractionDigits: Int { exponent }
}

private extension AlgorandContract.Units {
    var exponent: Int {
        switch self {
        case .microalgo: return 0
        case .algo: return 6
        }
    }
}

extension AlgorandContract {
    /// Whether `address` is an account, 58 characters of upper-case base32, or a standard asset's numeric id
    ///
    /// The account's checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        if address.count == 58 {
            return address.unicodeScalars.allSatisfy { ("A"..."Z").contains($0) || ("2"..."7").contains($0) }
        }
        return !address.isEmpty && address.allSatisfy { $0.isASCII && $0.isNumber } && UInt64(address) != nil
    }
}
