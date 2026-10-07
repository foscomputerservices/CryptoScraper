// CardanoContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Cardano: a Shelley address, bech32 `addr1` in lower case; a Byron address, base58 beginning `Ae2` or
/// `DdzFF`; or a native asset, its policy id (56 lower-case hex digits) and its name (up to 64 more, whole bytes, so
/// an even count); kept as given
public struct CardanoContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Cardano's ladder: lovelace to ADA, the base unit at exponent 0 and the chain's coin at 6
    public enum Units: String, CurrencyUnits {
        case lovelace
        case ada

        public static var chainBaseUnits: Self { .lovelace }
        public static var defaultDisplayUnits: Self { .ada }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = CardanoChain

    /// The contract's address
    public let address: String

    /// Initializes the ``CardanoContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension CardanoContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension CardanoContract {
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

public extension CardanoContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 6 for ADA
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "ADA" for the whole unit, "ADA(lovelace)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .ada
            ? "ADA"
            : "ADA(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 6 digits in ADA
    var displayFractionDigits: Int { exponent }
}

private extension CardanoContract.Units {
    var exponent: Int {
        switch self {
        case .lovelace: return 0
        case .ada: return 6
        }
    }
}

extension CardanoContract {
    /// Whether `address` is a Shelley address, bech32 `addr1` in lower case; a Byron address, base58 beginning `Ae2` or
    /// `DdzFF`; or a native asset, its policy id (56 lower-case hex digits) and its name (up to 64 more, whole bytes, so
    /// an even count)
    ///
    /// Read by shape; no checksum is verified unless this says so.
    static func isWellFormed(_ address: String) -> Bool {
        if address.hasPrefix("addr1") {
            let data = address.dropFirst(5)
            return (53...120).contains(data.count) && data.allSatisfy { BitcoinContract.bech32Alphabet.contains($0) }
        }
        if address.hasPrefix("Ae2") || address.hasPrefix("DdzFF") {
            return BitcoinContract.base58Bytes(address) != nil
        }
        return (56...120).contains(address.count) && address.count.isMultiple(of: 2)
            && address.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

}
