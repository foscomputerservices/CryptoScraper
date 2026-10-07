// NeoContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Neo N3: an account address (`N…`, 34 characters of base58) or a contract's script hash (`0x` and 40
/// hex digits); kept as given
public struct NeoContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Neo's ladder: NEO is indivisible, so its one unit is both the base unit and the whole unit, exponent 0
    public enum Units: String, CurrencyUnits {
        case neo

        public static var chainBaseUnits: Self { .neo }
        public static var defaultDisplayUnits: Self { .neo }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = NeoChain

    /// The contract's address
    public let address: String

    /// Initializes the ``NeoContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension NeoContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension NeoContract {
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

public extension NeoContract.Units {
    /// One: the base unit and the whole unit are one, exponent 0
    var divisorFromBase: UInt128 { 1 }

    /// "NEO"
    var displayIdentifier: String { "NEO" }

    /// No fraction: NEO is indivisible
    var displayFractionDigits: Int { 0 }
}

extension NeoContract {
    /// Whether `address` is an address, `N` and 33 more characters of base58, or a contract's script hash, `0x` and
    /// 40 hex digits
    ///
    /// The address's checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        if address.hasPrefix("0x") {
            return address.count == 42 && address.dropFirst(2).allSatisfy(\.isHexDigit)
        }
        return address.count == 34 && address.first == "N" && address.allSatisfy { alphabet.contains($0) }
    }

    private static let alphabet = Set("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
}
