// DecredContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Decred: an address, base58 decoding to a two-byte version and a 20-byte hash: `Ds` (0x073f), `Dc`
/// (0x071a), `De` (0x071f) or `DS` (0x0701), as dcrd's mainnet parameters state them; kept as given
public struct DecredContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Decred's ladder: atoms to DCR, the base unit at exponent 0 and the chain's coin at 8
    public enum Units: String, CurrencyUnits {
        case atom
        case dcr

        public static var chainBaseUnits: Self { .atom }
        public static var defaultDisplayUnits: Self { .dcr }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = DecredChain

    /// The contract's address
    public let address: String

    /// Initializes the ``DecredContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension DecredContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension DecredContract {
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

public extension DecredContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for DCR
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "DCR" for the whole unit, "DCR(atom)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .dcr
            ? "DCR"
            : "DCR(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in DCR
    var displayFractionDigits: Int { exponent }
}

private extension DecredContract.Units {
    var exponent: Int {
        switch self {
        case .atom: return 0
        case .dcr: return 8
        }
    }
}

extension DecredContract {
    /// Whether `address` is an address, base58 decoding to a two-byte version and a 20-byte hash: `Ds` (0x073f), `Dc`
    /// (0x071a), `De` (0x071f) or `DS` (0x0701), as dcrd's mainnet parameters state them
    ///
    /// Read by shape; no checksum is verified unless this says so.
    static func isWellFormed(_ address: String) -> Bool {
        guard let bytes = BitcoinContract.base58Bytes(address), bytes.count == 2 + 20 + 4 else {
            return false
        }
        return [[0x07, 0x3F], [0x07, 0x1A], [0x07, 0x1F], [0x07, 0x01]].contains(Array(bytes.prefix(2)))
    }

}
