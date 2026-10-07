// StellarContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Stellar: an account (`G…`) or a contract (`C…`), 56 characters of upper-case base32 (StrKey), or a
/// classic asset as `<code>-<issuer>`; kept as given
public struct StellarContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Stellar's ladder: stroops to XLM, the base unit at exponent 0 and the chain's coin at 7
    public enum Units: String, CurrencyUnits {
        case stroop
        case xlm

        public static var chainBaseUnits: Self { .stroop }
        public static var defaultDisplayUnits: Self { .xlm }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = StellarChain

    /// The contract's address
    public let address: String

    /// Initializes the ``StellarContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension StellarContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension StellarContract {
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

public extension StellarContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 7 for XLM
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "XLM" for the whole unit, "XLM(stroop)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .xlm
            ? "XLM"
            : "XLM(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 7 digits in XLM
    var displayFractionDigits: Int { exponent }
}

private extension StellarContract.Units {
    var exponent: Int {
        switch self {
        case .stroop: return 0
        case .xlm: return 7
        }
    }
}

extension StellarContract {
    /// Whether `address` is a StrKey account (`G…`) or contract (`C…`), 56 characters of upper-case base32, or a
    /// classic asset as CoinGecko writes it, `<code>-<issuer>`: 1 to 12 letters or digits, then an account
    ///
    /// The StrKey checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        let parts = address.split(separator: "-", omittingEmptySubsequences: false)
        switch parts.count {
        case 1:
            return isStrKey(parts[0], kinds: ["G", "C"])
        case 2:
            return (1...12).contains(parts[0].count)
                && parts[0].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
                && isStrKey(parts[1], kinds: ["G"])
        default:
            return false
        }
    }

    private static func isStrKey(_ text: Substring, kinds: Set<Character>) -> Bool {
        guard text.count == 56, let first = text.first, kinds.contains(first) else {
            return false
        }
        return text.unicodeScalars.allSatisfy { ("A"..."Z").contains($0) || ("2"..."7").contains($0) }
    }
}
