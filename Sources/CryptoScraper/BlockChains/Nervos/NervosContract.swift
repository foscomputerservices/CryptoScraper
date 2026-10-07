// NervosContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Nervos: an address, `ckb1` and at least 42 characters of bech32's alphabet in lower case, RFC 0021's
/// full format (bech32m) or its deprecated short one (bech32); kept as given
public struct NervosContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Nervos's ladder: shannons to CKB, the base unit at exponent 0 and the chain's coin at 8
    public enum Units: String, CurrencyUnits {
        case shannon
        case ckb

        public static var chainBaseUnits: Self { .shannon }
        public static var defaultDisplayUnits: Self { .ckb }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = NervosChain

    /// The contract's address
    public let address: String

    /// Initializes the ``NervosContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension NervosContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension NervosContract {
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

public extension NervosContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for CKB
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "CKB" for the whole unit, "CKB(shannon)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .ckb
            ? "CKB"
            : "CKB(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in CKB
    var displayFractionDigits: Int { exponent }
}

private extension NervosContract.Units {
    var exponent: Int {
        switch self {
        case .shannon: return 0
        case .ckb: return 8
        }
    }
}

extension NervosContract {
    /// Whether `address` is an address, `ckb1` and at least 42 characters of bech32's alphabet in lower case, RFC
    /// 0021's full format (bech32m) or its deprecated short one (bech32)
    ///
    /// Read by shape; no checksum is verified unless this says so.
    static func isWellFormed(_ address: String) -> Bool {
        guard address.hasPrefix("ckb1") else {
            return false
        }
        let data = address.dropFirst(4)
        return (42...1000).contains(data.count) && data.allSatisfy { BitcoinContract.bech32Alphabet.contains($0) }
    }

}
