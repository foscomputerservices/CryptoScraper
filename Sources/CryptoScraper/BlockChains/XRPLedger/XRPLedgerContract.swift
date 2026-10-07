// XRPLedgerContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on the XRP Ledger: a classic account address (`r…`, base58 in the ledger's alphabet), or an issued token
/// as `<currency>.<issuer>`; kept as given (base58 is case-sensitive)
public struct XRPLedgerContract: CryptoContract, Codable, Stubbable, Sendable {
    /// XRP Ledger's ladder: drops to XRP, the base unit at exponent 0 and the chain's coin at 6
    public enum Units: String, CurrencyUnits {
        case drop
        case xrp

        public static var chainBaseUnits: Self { .drop }
        public static var defaultDisplayUnits: Self { .xrp }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = XRPLedgerChain

    /// The contract's address
    public let address: String

    /// Initializes the ``XRPLedgerContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension XRPLedgerContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension XRPLedgerContract {
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

public extension XRPLedgerContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 6 for XRP
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "XRP" for the whole unit, "XRP(drop)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .xrp
            ? "XRP"
            : "XRP(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 6 digits in XRP
    var displayFractionDigits: Int { exponent }
}

private extension XRPLedgerContract.Units {
    var exponent: Int {
        switch self {
        case .drop: return 0
        case .xrp: return 6
        }
    }
}

extension XRPLedgerContract {
    /// Whether `address` is a classic address, `r` and 24 to 34 more characters of the ledger's base58 alphabet, or a
    /// token as `<currency>.<issuer>`: a 3-character code or 40 hex digits, then a classic address (CoinGecko's form)
    ///
    /// The checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        let parts = address.split(separator: ".", omittingEmptySubsequences: false)
        switch parts.count {
        case 1:
            return isClassicAddress(parts[0])
        case 2:
            return isCurrencyCode(parts[0]) && isClassicAddress(parts[1])
        default:
            return false
        }
    }

    private static let alphabet = Set("rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz")

    private static func isClassicAddress(_ text: Substring) -> Bool {
        text.first == "r" && (25...35).contains(text.count) && text.allSatisfy { alphabet.contains($0) }
    }

    private static func isCurrencyCode(_ text: Substring) -> Bool {
        if text.count == 3 {
            return text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } && text != "XRP"
        }
        return text.count == 40 && text.allSatisfy(\.isHexDigit)
    }
}
