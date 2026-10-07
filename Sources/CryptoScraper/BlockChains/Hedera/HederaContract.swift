// HederaContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Hedera: an entity id, `<shard>.<realm>.<num>` in decimal (an account or a token), normalized to its
/// numbers without leading zeros
public struct HederaContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Hedera's ladder: tinybars to HBAR, the base unit at exponent 0 and the chain's coin at 8
    public enum Units: String, CurrencyUnits {
        case tinybar
        case hbar

        public static var chainBaseUnits: Self { .tinybar }
        public static var defaultDisplayUnits: Self { .hbar }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = HederaChain

    /// The contract's address
    public let address: String

    /// Initializes the ``HederaContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = Self.normalized(address)
    }
}

public extension HederaContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension HederaContract {
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

public extension HederaContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for HBAR
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "HBAR" for the whole unit, "HBAR(tinybar)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .hbar
            ? "HBAR"
            : "HBAR(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in HBAR
    var displayFractionDigits: Int { exponent }
}

private extension HederaContract.Units {
    var exponent: Int {
        switch self {
        case .tinybar: return 0
        case .hbar: return 8
        }
    }
}

extension HederaContract {
    /// Whether `address` is an entity id, `<shard>.<realm>.<num>`, three numbers in decimal
    static func isWellFormed(_ address: String) -> Bool {
        entityNumbers(address) != nil
    }

    /// The entity id's three numbers without leading zeros, `0.0.098` → `0.0.98`; any other text as given
    static func normalized(_ address: String) -> String {
        guard let numbers = entityNumbers(address) else {
            return address
        }
        return numbers.map(String.init).joined(separator: ".")
    }

    private static func entityNumbers(_ address: String) -> [UInt64]? {
        let parts = address.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            return nil
        }
        let numbers = parts.compactMap { part -> UInt64? in
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            return UInt64(part)
        }
        return numbers.count == 3 ? numbers : nil
    }
}
