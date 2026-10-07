// OntologyContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Ontology: an address, `A` and 33 more characters of base58 decoding to version 23 (0x17) and a 20-byte
/// hash, or an OEP-4 contract's hash, 40 lower-case hex digits; kept as given
public struct OntologyContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Ontology's ladder: the chain's count to ONT, the base unit at exponent 0 and the chain's coin at 9; ONG, the
    /// second native coin, at 18 is stated in the shared statement, not here
    public enum Units: String, CurrencyUnits {
        case base
        case ont

        public static var chainBaseUnits: Self { .base }
        public static var defaultDisplayUnits: Self { .ont }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = OntologyChain

    /// The contract's address
    public let address: String

    /// Initializes the ``OntologyContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension OntologyContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension OntologyContract {
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

public extension OntologyContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 9 for ONT
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "ONT" for the whole unit, "ONT(base)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .ont
            ? "ONT"
            : "ONT(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 9 digits in ONT
    var displayFractionDigits: Int { exponent }
}

private extension OntologyContract.Units {
    var exponent: Int {
        switch self {
        case .base: return 0
        case .ont: return 9
        }
    }
}

extension OntologyContract {
    /// Whether `address` is an address, `A` and 33 more characters of base58 decoding to version 23 (0x17) and a
    /// 20-byte hash, or an OEP-4 contract's hash, 40 lower-case hex digits
    ///
    /// Read by shape; no checksum is verified unless this says so.
    static func isWellFormed(_ address: String) -> Bool {
        if address.count == 34, let bytes = BitcoinContract.base58Bytes(address) {
            return bytes.count == 25 && bytes[0] == 0x17
        }
        return address.count == 40 && address.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

}
