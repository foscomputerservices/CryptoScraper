// TezosContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Tezos: an implicit account (`tz1`, `tz2`, `tz3`) or an originated contract (`KT1`), 36 characters of
/// base58; kept as given (base58 is case-sensitive)
public struct TezosContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Tezos's ladder: mutez to XTZ, the base unit at exponent 0 and the chain's coin at 6
    public enum Units: String, CurrencyUnits {
        case mutez
        case xtz

        public static var chainBaseUnits: Self { .mutez }
        public static var defaultDisplayUnits: Self { .xtz }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = TezosChain

    /// The contract's address
    public let address: String

    /// Initializes the ``TezosContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension TezosContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension TezosContract {
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

public extension TezosContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 6 for XTZ
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "XTZ" for the whole unit, "XTZ(mutez)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .xtz
            ? "XTZ"
            : "XTZ(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 6 digits in XTZ
    var displayFractionDigits: Int { exponent }
}

private extension TezosContract.Units {
    var exponent: Int {
        switch self {
        case .mutez: return 0
        case .xtz: return 6
        }
    }
}

extension TezosContract {
    /// Whether `address` is `tz1`, `tz2`, `tz3` or `KT1` and 33 more characters of base58, 36 in all
    ///
    /// The base58check checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        guard address.count == 36, ["tz1", "tz2", "tz3", "KT1"].contains(String(address.prefix(3))) else {
            return false
        }
        return address.allSatisfy { alphabet.contains($0) }
    }

    private static let alphabet = Set("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
}
