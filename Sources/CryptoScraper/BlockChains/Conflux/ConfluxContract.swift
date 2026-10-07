// ConfluxContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Conflux core space: a CIP-37 base32 address (`cfx:` and 42 characters), held as CAIP-10 writes it, its
/// body alone in lower case, the network prefix and the optional fields (`type.user:`) dropped
public struct ConfluxContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Conflux's ladder: drip to CFX, the base unit at exponent 0 and the chain's coin at 18
    public enum Units: String, CurrencyUnits {
        case drip
        case cfx

        public static var chainBaseUnits: Self { .drip }
        public static var defaultDisplayUnits: Self { .cfx }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = ConfluxChain

    /// The contract's address
    public let address: String

    /// Initializes the ``ConfluxContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = Self.normalized(address)
    }
}

public extension ConfluxContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension ConfluxContract {
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

public extension ConfluxContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 18 for CFX
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "CFX" for the whole unit, "CFX(drip)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .cfx
            ? "CFX"
            : "CFX(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 18 digits in CFX
    var displayFractionDigits: Int { exponent }
}

private extension ConfluxContract.Units {
    var exponent: Int {
        switch self {
        case .drip: return 0
        case .cfx: return 18
        }
    }
}

extension ConfluxContract {
    /// Whether `address` is a CIP-37 mainnet address's body, as ``normalized(_:)`` leaves it: 42 characters of
    /// CIP-37's base32 alphabet, the first `a`, since CIP-37's version byte is 0 (an eSpace hex address, `0x` and 40
    /// hex digits, is 42 characters of the alphabet too, and is refused by its first)
    ///
    /// The address's checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        address.count == 42 && address.first == "a" && address.allSatisfy { alphabet.contains($0) }
    }

    /// CAIP-10's text of a core space account (`conflux:cfx:<body>`): the CIP-37 address's body in lower case, its
    /// network prefix `cfx:` and its optional fields dropped, `CFX:TYPE.USER:AARC…` → `aarc…`; a text with no `:` in
    /// one case, lower-cased (`AARC…` → `aarc…`); any other text as given
    ///
    /// CIP-37 writes an address all in upper or all in lower case; mixed case is no address, so it is kept as given
    /// and refused. A testnet address keeps its prefix, so it is refused too.
    static func normalized(_ address: String) -> String {
        guard address == address.lowercased() || address == address.uppercased() else {
            return address
        }
        let parts = address.lowercased().split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 2 else {
            return address.lowercased()
        }
        guard parts.first == "cfx", parts.dropFirst().dropLast().allSatisfy({ $0.hasPrefix("type.") }) else {
            return address
        }
        return String(parts.last!)
    }

    /// The address as the node reads it, its network prefix put back: `cfx:<body>`
    var cip37Address: String {
        "cfx:" + address
    }

    private static let alphabet = Set("abcdefghjkmnprstuvwxyz0123456789")
}
