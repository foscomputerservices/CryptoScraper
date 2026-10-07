// QtumContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Qtum: an address, base58 of a 20-byte hash whose version is 58 (`Q`) or 50 (`M`), or a
/// segregated-witness address, `qc1` in lower case, or a QRC-20 contract, 40 hex digits; a contract's hex in lower
/// case, every other address kept as given (base58 is case-sensitive)
public struct QtumContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Qtum's ladder: the chain's count to QTUM, the base unit at exponent 0 and the chain's coin at 8
    public enum Units: String, CurrencyUnits {
        case base
        case qtum

        public static var chainBaseUnits: Self { .base }
        public static var defaultDisplayUnits: Self { .qtum }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = QtumChain

    /// The contract's address
    public let address: String

    /// Initializes the ``QtumContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = Self.normalized(address)
    }
}

public extension QtumContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension QtumContract {
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

public extension QtumContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for QTUM
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "QTUM" for the whole unit, "QTUM(base)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .qtum
            ? "QTUM"
            : "QTUM(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in QTUM
    var displayFractionDigits: Int { exponent }
}

private extension QtumContract.Units {
    var exponent: Int {
        switch self {
        case .base: return 0
        case .qtum: return 8
        }
    }
}

extension QtumContract {
    /// Whether `address` is base58 of a 20-byte hash whose version is 58 (`Q`) or 50 (`M`), or a segregated-witness
    /// address, `qc1` in lower case, or a QRC-20 contract, 40 hex digits
    ///
    /// No checksum is verified.
    static func isWellFormed(_ address: String) -> Bool {
        BitcoinContract.base58AddressVersion(address).map { versions.contains($0) } == true
            || BitcoinContract.isWitnessAddress(address, humanReadablePart: "qc")
            || isContractHex(address)
    }

    private static let versions: Set<Int> = [58, 50]

    /// A QRC-20 contract's address, 40 hex digits, in lower case; any other address as given (base58 is
    /// case-sensitive)
    static func normalized(_ address: String) -> String {
        isContractHex(address.lowercased()) ? address.lowercased() : address
    }

    /// Whether `text` is a contract's address as Qtum writes it, 40 hex digits in lower case, no `0x`
    private static func isContractHex(_ text: String) -> Bool {
        text.count == 40 && text.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }
}
