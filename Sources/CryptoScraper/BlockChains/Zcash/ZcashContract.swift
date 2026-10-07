// ZcashContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Zcash: an address, base58 of a 20-byte hash whose version is 0x1cb8 (`t1`) or 0x1cbd (`t3`); kept as
/// given (base58 is case-sensitive). A shielded address (`zc…`, `zs1…`, `u1…`) is no contract: only a transparent
/// address is read
public struct ZcashContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Zcash's ladder: zatoshis to ZEC, the base unit at exponent 0 and the chain's coin at 8
    public enum Units: String, CurrencyUnits {
        case zatoshi
        case zec

        public static var chainBaseUnits: Self { .zatoshi }
        public static var defaultDisplayUnits: Self { .zec }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = ZcashChain

    /// The contract's address
    public let address: String

    /// Initializes the ``ZcashContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension ZcashContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension ZcashContract {
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

public extension ZcashContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for ZEC
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "ZEC" for the whole unit, "ZEC(zatoshi)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .zec
            ? "ZEC"
            : "ZEC(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in ZEC
    var displayFractionDigits: Int { exponent }
}

private extension ZcashContract.Units {
    var exponent: Int {
        switch self {
        case .zatoshi: return 0
        case .zec: return 8
        }
    }
}

extension ZcashContract {
    /// Whether `address` is base58 of a 20-byte hash whose version is 0x1cb8 (`t1`) or 0x1cbd (`t3`)
    ///
    /// No checksum is verified.
    static func isWellFormed(_ address: String) -> Bool {
        BitcoinContract.base58AddressVersion(address, versionByteCount: 2).map { versions.contains($0) } == true
    }

    private static let versions: Set<Int> = [0x1cb8, 0x1cbd]

    /// Whether `address` is a shielded one: a Sapling address (`zs1…`), a unified address (`u1…`), or a Sprout
    /// address (`zc…`, base58 of version `0x169a` and 64 bytes)
    static func isShielded(_ address: String) -> Bool {
        address.hasPrefix("zs1") || address.hasPrefix("u1")
            || BitcoinContract.base58Bytes(address).map { bytes in
                bytes.count == 2 + 64 + 4 && bytes.prefix(2) == [0x16, 0x9A]
            } == true
    }
}
