// StacksContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Stacks: a principal, `SP` or `SM` and c32check (23 to 41 characters in all: c32check writes each
/// leading zero byte of the hash as one `0`, so the boot address `SP000000000000000000002Q6VF78` has 29), or a contract
/// as `<principal>.<contract-name>`; kept as given
public struct StacksContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Stacks's ladder: microSTX to STX, the base unit at exponent 0 and the chain's coin at 6
    public enum Units: String, CurrencyUnits {
        case microstx
        case stx

        public static var chainBaseUnits: Self { .microstx }
        public static var defaultDisplayUnits: Self { .stx }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = StacksChain

    /// The contract's address
    public let address: String

    /// Initializes the ``StacksContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension StacksContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension StacksContract {
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

public extension StacksContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 6 for STX
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "STX" for the whole unit, "STX(microstx)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .stx
            ? "STX"
            : "STX(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 6 digits in STX
    var displayFractionDigits: Int { exponent }
}

private extension StacksContract.Units {
    var exponent: Int {
        switch self {
        case .microstx: return 0
        case .stx: return 6
        }
    }
}

extension StacksContract {
    /// Whether `address` is a principal, `SP` or `SM` and c32check (23 to 41 characters in all: c32check writes each
    /// leading zero byte of the hash as one `0`, so the boot address `SP000000000000000000002Q6VF78` has 29), or a
    /// contract,
    /// `<principal>.<contract-name>`, the name a letter and up to 127 more letters, digits, `-` or `_`
    ///
    /// The c32check checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        let parts = address.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard isPrincipal(parts[0]) else {
            return false
        }
        guard parts.count == 2 else {
            return true
        }
        let name = parts[1]
        return (1...128).contains(name.count) && name.first!.isASCII && name.first!.isLetter
            && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    private static func isPrincipal(_ text: Substring) -> Bool {
        (23...41).contains(text.count) && (text.hasPrefix("SP") || text.hasPrefix("SM"))
            && text.allSatisfy { c32.contains($0) }
    }

    private static let c32 = Set("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
}
