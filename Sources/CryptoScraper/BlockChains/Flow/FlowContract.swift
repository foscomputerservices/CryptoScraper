// FlowContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Flow: an account, `0x` and 16 hex digits, in lower case, or a contract as Cadence names it, `A.<16 hex
/// digits>.<ContractName>`
public struct FlowContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Flow's ladder: the chain's count to FLOW, the base unit at exponent 0 and the chain's coin at 8; the chain names
    /// no unit below its coin, so the count is `base`, the word an exchange holding's ladder uses
    public enum Units: String, CurrencyUnits {
        case base
        case flow

        public static var chainBaseUnits: Self { .base }
        public static var defaultDisplayUnits: Self { .flow }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = FlowChain

    /// The contract's address
    public let address: String

    /// Initializes the ``FlowContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = Self.normalized(address)
    }
}

public extension FlowContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension FlowContract {
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

public extension FlowContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for FLOW
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "FLOW" for the whole unit, "FLOW(base)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .flow
            ? "FLOW"
            : "FLOW(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in FLOW
    var displayFractionDigits: Int { exponent }
}

private extension FlowContract.Units {
    var exponent: Int {
        switch self {
        case .base: return 0
        case .flow: return 8
        }
    }
}

extension FlowContract {
    /// Whether `address` is an account, `0x` and 16 hex digits, or a contract as Cadence names it,
    /// `A.<16 hex digits>.<ContractName>`
    static func isWellFormed(_ address: String) -> Bool {
        if address.hasPrefix("0x") {
            return address.count == 18 && address.dropFirst(2).allSatisfy(\.isHexDigit)
        }
        let parts = address.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 3 && parts[0] == "A"
            && parts[1].count == 16 && parts[1].allSatisfy(\.isHexDigit)
            && !parts[2].isEmpty && parts[2].first!.isLetter
            && parts[2].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
    }

    /// An account's hex in lower case, `0xABC…` → `0xabc…`, since it is a number; any other text as given
    static func normalized(_ address: String) -> String {
        address.hasPrefix("0x") ? address.lowercased() : address
    }
}
