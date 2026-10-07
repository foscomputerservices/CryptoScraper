// BitcoinCashContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Bitcoin Cash: an address, a CashAddr, `bitcoincash:` and `q` or `p` and 41 more characters, all in
/// lower or all in upper case, its prefix optional, or a legacy address, base58 of a 20-byte hash whose version is 0
/// (`1`) or 5 (`3`); a CashAddr is held as its body alone, in lower case
public struct BitcoinCashContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Bitcoin Cash's ladder: satoshi to BCH, the base unit at exponent 0 and the chain's coin at 8
    public enum Units: String, CurrencyUnits {
        case satoshi
        case bch

        public static var chainBaseUnits: Self { .satoshi }
        public static var defaultDisplayUnits: Self { .bch }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = BitcoinCashChain

    /// The contract's address
    public let address: String

    /// Initializes the ``BitcoinCashContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = Self.normalized(address)
    }
}

public extension BitcoinCashContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension BitcoinCashContract {
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

public extension BitcoinCashContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for BCH
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "BCH" for the whole unit, "BCH(satoshi)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .bch
            ? "BCH"
            : "BCH(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in BCH
    var displayFractionDigits: Int { exponent }
}

private extension BitcoinCashContract.Units {
    var exponent: Int {
        switch self {
        case .satoshi: return 0
        case .bch: return 8
        }
    }
}

extension BitcoinCashContract {
    /// Whether `address` is a CashAddr's body as ``normalized(_:)`` leaves it, `q` or `p` and 41 more characters of its
    /// alphabet in lower case, or a legacy address, base58 of a 20-byte hash whose version is 0 (`1`) or 5 (`3`)
    ///
    /// No checksum is verified.
    static func isWellFormed(_ address: String) -> Bool {
        isCashAddrBody(address)
            || BitcoinContract.base58AddressVersion(address).map { versions.contains($0) } == true
    }

    private static let versions: Set<Int> = [0, 5]

    /// The CashAddr prefix of the chain's mainnet
    static let prefix = "bitcoincash:"

    /// CAIP-10's text of a CashAddr: its body in lower case, its `bitcoincash:` prefix dropped,
    /// `BITCOINCASH:QPM2…` → `qpm2…`; any other text as given
    ///
    /// CashAddr writes an address all in lower or all in upper case; mixed case is no address, so it is kept as given
    /// and refused, as is another network's prefix. A legacy address is base58, so it is kept as given.
    static func normalized(_ address: String) -> String {
        guard address == address.lowercased() || address == address.uppercased() else {
            return address
        }
        let lower = address.lowercased()
        let body = lower.hasPrefix(prefix) ? String(lower.dropFirst(prefix.count)) : lower
        return isCashAddrBody(body) ? body : address
    }

    /// The address as Blockchair is asked for it: a CashAddr's body with its prefix put back, a legacy address as
    /// given
    var cashAddress: String {
        Self.isCashAddrBody(address) ? Self.prefix + address : address
    }

    /// Whether `text` is a CashAddr body of a 20-byte hash: `q` (a key hash) or `p` (a script hash) and 41 more
    /// characters of its alphabet, in lower case
    private static func isCashAddrBody(_ text: String) -> Bool {
        text.count == 42 && (text.first == "q" || text.first == "p")
            && text.allSatisfy { BitcoinContract.bech32Alphabet.contains($0) }
    }
}
