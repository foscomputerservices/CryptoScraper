// ZilliqaContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Zilliqa: an address, bech32 `zil1` of 20 bytes in lower case, its checksum verified; a 20-byte hex
/// address (`0x` and 40 hex digits) is accepted and written as its bech32; normalized to its bech32
public struct ZilliqaContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Zilliqa's ladder: Qa to ZIL, the base unit at exponent 0 and the chain's coin at 12
    public enum Units: String, CurrencyUnits {
        case qa
        case zil

        public static var chainBaseUnits: Self { .qa }
        public static var defaultDisplayUnits: Self { .zil }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = ZilliqaChain

    /// The contract's address
    public let address: String

    /// Initializes the ``ZilliqaContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = Self.normalized(address)
    }
}

public extension ZilliqaContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension ZilliqaContract {
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

public extension ZilliqaContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 12 for ZIL
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "ZIL" for the whole unit, "ZIL(qa)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .zil
            ? "ZIL"
            : "ZIL(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 12 digits in ZIL
    var displayFractionDigits: Int { exponent }
}

private extension ZilliqaContract.Units {
    var exponent: Int {
        switch self {
        case .qa: return 0
        case .zil: return 12
        }
    }
}

extension ZilliqaContract {
    /// Whether `address` is an address, bech32 `zil1` of 20 bytes in lower case, its checksum verified; a 20-byte hex
    /// address (`0x` and 40 hex digits) is accepted and written as its bech32
    ///
    /// Read by shape; no checksum is verified unless this says so.
    static func isWellFormed(_ address: String) -> Bool {
        ZilliqaContract.bytes(bech32: address)?.count == 20
    }

    /// The address as the chain writes it canonically: normalized to its bech32; any other text as given
    static func normalized(_ address: String) -> String {
        guard address.count == 42, address.lowercased().hasPrefix("0x"),
              let bytes = ZilliqaContract.bytes(hex: address.dropFirst(2)), bytes.count == 20 else {
            return address
        }
        return ZilliqaContract.bech32(bytes)
    }

}
