// NearContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on NEAR: an account id: a named account (2 to 64 characters, lower-case letters and digits in parts
/// joined by `.`, each part's characters joined by single `-` or `_`, as `wrap.near`) or an implicit account (64
/// lower-case hex digits), each written in lower case only; kept as given
public struct NearContract: CryptoContract, Codable, Stubbable, Sendable {
    /// NEAR's ladder: yoctoNEAR to NEAR, the base unit at exponent 0 and the chain's coin at 24
    public enum Units: String, CurrencyUnits {
        case yoctonear
        case near

        public static var chainBaseUnits: Self { .yoctonear }
        public static var defaultDisplayUnits: Self { .near }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = NearChain

    /// The contract's address
    public let address: String

    /// Initializes the ``NearContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension NearContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension NearContract {
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

public extension NearContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 24 for NEAR
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "NEAR" for the whole unit, "NEAR(yoctonear)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .near
            ? "NEAR"
            : "NEAR(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 24 digits in NEAR
    var displayFractionDigits: Int { exponent }
}

private extension NearContract.Units {
    var exponent: Int {
        switch self {
        case .yoctonear: return 0
        case .near: return 24
        }
    }
}

extension NearContract {
    /// Whether `address` is an account id: a named account (2 to 64 characters, lower-case letters and digits in parts
    /// joined by `.`, each part's characters joined by single `-` or `_`, as `wrap.near`) or an implicit account (64
    /// lower-case hex digits), each written in lower case only
    ///
    /// Read by shape; no checksum is verified unless this says so.
    static func isWellFormed(_ address: String) -> Bool {
        guard (2...64).contains(address.count) else {
            return false
        }
        return address.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { part in
            guard let first = part.first, let last = part.last,
                  isAccountCharacter(first), isAccountCharacter(last) else {
                return false
            }
            var afterSeparator = false
            for character in part {
                if isAccountCharacter(character) {
                    afterSeparator = false
                } else if (character == "-" || character == "_") && !afterSeparator {
                    afterSeparator = true
                } else {
                    return false
                }
            }
            return true
        }
    }

    /// A lower-case ASCII letter or a digit, the characters of an account id's parts
    private static func isAccountCharacter(_ character: Character) -> Bool {
        character.isASCII && (character.isLowercase || character.isNumber)
    }
}
