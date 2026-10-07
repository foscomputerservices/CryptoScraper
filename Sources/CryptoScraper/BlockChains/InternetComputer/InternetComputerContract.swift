// InternetComputerContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Internet Computer: an account identifier, 64 hex digits, lower-cased (a principal is no account: it is
/// refused as one); lower-cased
public struct InternetComputerContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Internet Computer's ladder: e8s to ICP, the base unit at exponent 0 and the chain's coin at 8
    public enum Units: String, CurrencyUnits {
        case e8s
        case icp

        public static var chainBaseUnits: Self { .e8s }
        public static var defaultDisplayUnits: Self { .icp }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = InternetComputerChain

    /// The contract's address
    public let address: String

    /// Initializes the ``InternetComputerContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = Self.normalized(address)
    }
}

public extension InternetComputerContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension InternetComputerContract {
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

public extension InternetComputerContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 8 for ICP
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "ICP" for the whole unit, "ICP(e8s)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .icp
            ? "ICP"
            : "ICP(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 8 digits in ICP
    var displayFractionDigits: Int { exponent }
}

private extension InternetComputerContract.Units {
    var exponent: Int {
        switch self {
        case .e8s: return 0
        case .icp: return 8
        }
    }
}

extension InternetComputerContract {
    /// Whether `address` is an account identifier, 64 hex digits, lower-cased (a principal is no account: it is refused
    /// as one)
    ///
    /// Read by shape; no checksum is verified unless this says so.
    static func isWellFormed(_ address: String) -> Bool {
        address.count == 64 && address.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    /// The address as the chain writes it canonically: lower-cased; any other text as given
    static func normalized(_ address: String) -> String {
        guard address.count == 64, address.allSatisfy(\.isHexDigit) else {
            return address
        }
        return address.lowercased()
    }

    /// Whether `text` is a principal's text form: groups of five lower-case base32 characters joined by `-`, the
    /// last of one to five
    static func isPrincipal(_ text: String) -> Bool {
        let groups = text.split(separator: "-", omittingEmptySubsequences: false)
        guard groups.count >= 2, let last = groups.last, (1...5).contains(last.count),
              groups.dropLast().allSatisfy({ $0.count == 5 }) else {
            return false
        }
        return groups.allSatisfy { group in
            group.allSatisfy { $0.isASCII && ($0.isLowercase || ("2"..."7").contains($0)) }
        }
    }
}
