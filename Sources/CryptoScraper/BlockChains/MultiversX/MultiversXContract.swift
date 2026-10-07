// MultiversXContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on MultiversX: an address, bech32 `erd1` and 58 more characters (62 in all), or an ESDT token by its
/// identifier, `<TICKER>-<6 hex digits>`; kept as given
public struct MultiversXContract: CryptoContract, Codable, Stubbable, Sendable {
    /// MultiversX's ladder: the chain's count to EGLD, the base unit at exponent 0 and the chain's coin at 18; the
    /// chain names no
    /// unit below its coin, so the count is `base`, the word an exchange holding's ladder uses
    public enum Units: String, CurrencyUnits {
        case base
        case egld

        public static var chainBaseUnits: Self { .base }
        public static var defaultDisplayUnits: Self { .egld }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = MultiversXChain

    /// The contract's address
    public let address: String

    /// Initializes the ``MultiversXContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension MultiversXContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension MultiversXContract {
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

public extension MultiversXContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 18 for EGLD
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "EGLD" for the whole unit, "EGLD(base)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .egld
            ? "EGLD"
            : "EGLD(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 18 digits in EGLD
    var displayFractionDigits: Int { exponent }
}

private extension MultiversXContract.Units {
    var exponent: Int {
        switch self {
        case .base: return 0
        case .egld: return 18
        }
    }
}

extension MultiversXContract {
    /// Whether `address` is an address, `erd1` and 58 characters of bech32's lower-case alphabet, or an ESDT token
    /// identifier, a ticker of 3 to 10 upper-case letters or digits, `-`, and 6 lower-case hex digits
    ///
    /// The bech32 checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        if address.hasPrefix("erd1") {
            return address.count == 62 && address.dropFirst(4).allSatisfy { bech32.contains($0) }
        }
        let parts = address.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return false
        }
        let ticker = parts[0], suffix = parts[1]
        return (3...10).contains(ticker.count)
            && ticker.allSatisfy { $0.isASCII && ($0.isUppercase || $0.isNumber) }
            && suffix.count == 6 && suffix.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static let bech32 = Set("qpzry9x8gf2tvdw0s3jn54khce6mua7l")
}
