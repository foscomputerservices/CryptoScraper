// SiaContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Sia: an address, 76 hex digits (a 32-byte hash and its 6-byte checksum), lower-cased; lower-cased
public struct SiaContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Sia's ladder: hastings to SC, the base unit at exponent 0 and the chain's coin at 24
    public enum Units: String, CurrencyUnits {
        case hasting
        case sc

        public static var chainBaseUnits: Self { .hasting }
        public static var defaultDisplayUnits: Self { .sc }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = SiaChain

    /// The contract's address
    public let address: String

    /// Initializes the ``SiaContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = Self.normalized(address)
    }
}

public extension SiaContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension SiaContract {
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

public extension SiaContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 24 for SC
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "SC" for the whole unit, "SC(hasting)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .sc
            ? "SC"
            : "SC(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 24 digits in SC
    var displayFractionDigits: Int { exponent }
}

private extension SiaContract.Units {
    var exponent: Int {
        switch self {
        case .hasting: return 0
        case .sc: return 24
        }
    }
}

extension SiaContract {
    /// Whether `address` is an address, 76 hex digits (a 32-byte hash and its 6-byte checksum), lower-cased
    ///
    /// Read by shape; no checksum is verified unless this says so.
    static func isWellFormed(_ address: String) -> Bool {
        address.count == 76 && address.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    /// The address as the chain writes it canonically: lower-cased; any other text as given
    static func normalized(_ address: String) -> String {
        guard address.count == 76, address.allSatisfy(\.isHexDigit) else {
            return address
        }
        return address.lowercased()
    }

}
