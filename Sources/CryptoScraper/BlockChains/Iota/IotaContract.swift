// IotaContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on IOTA: an address or an object, `0x` and 64 hex digits, in lower case
public struct IotaContract: CryptoContract, Codable, Stubbable, Sendable {
    /// IOTA's ladder: nanos to IOTA, the base unit at exponent 0 and the chain's coin at 9
    public enum Units: String, CurrencyUnits {
        case nano
        case iota

        public static var chainBaseUnits: Self { .nano }
        public static var defaultDisplayUnits: Self { .iota }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = IotaChain

    /// The contract's address
    public let address: String

    /// Initializes the ``IotaContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = Self.normalized(address)
    }
}

public extension IotaContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension IotaContract {
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

public extension IotaContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 9 for IOTA
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "IOTA" for the whole unit, "IOTA(nano)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .iota
            ? "IOTA"
            : "IOTA(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 9 digits in IOTA
    var displayFractionDigits: Int { exponent }
}

private extension IotaContract.Units {
    var exponent: Int {
        switch self {
        case .nano: return 0
        case .iota: return 9
        }
    }
}

extension IotaContract {
    /// Whether `address` is an address or an object, `0x` and 64 hex digits
    ///
    /// A coin type, `<address>::<module>::<name>`, is no instance address: an instance's address holds no colon.
    static func isWellFormed(_ address: String) -> Bool {
        address.count == 66 && address.hasPrefix("0x") && address.dropFirst(2).allSatisfy(\.isHexDigit)
    }

    /// The address's hex in lower case, `0xABC…` → `0xabc…`, since the address is a number; any other text as given
    static func normalized(_ address: String) -> String {
        let candidate = address.lowercased()
        return isWellFormed(candidate) ? candidate : address
    }
}
