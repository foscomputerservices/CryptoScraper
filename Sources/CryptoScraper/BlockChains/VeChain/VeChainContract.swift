// VeChainContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on VeChain: an account or a contract, `0x` and 40 hex digits, as on an EVM chain; lower-cased
public struct VeChainContract: CryptoContract, Codable, Stubbable, Sendable {
    /// VeChain's ladder: wei to VET, the base unit at exponent 0 and the chain's coin at 18
    public enum Units: String, CurrencyUnits {
        case wei
        case vet

        public static var chainBaseUnits: Self { .wei }
        public static var defaultDisplayUnits: Self { .vet }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = VeChainChain

    /// The contract's address
    public let address: String

    /// Initializes the ``VeChainContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = Self.normalized(address)
    }
}

public extension VeChainContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension VeChainContract {
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

public extension VeChainContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 18 for VET
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "VET" for the whole unit, "VET(wei)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .vet
            ? "VET"
            : "VET(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 18 digits in VET
    var displayFractionDigits: Int { exponent }
}

private extension VeChainContract.Units {
    var exponent: Int {
        switch self {
        case .wei: return 0
        case .vet: return 18
        }
    }
}

extension VeChainContract {
    /// Whether `address` is `0x` and 40 hex digits, as on an EVM chain
    static func isWellFormed(_ address: String) -> Bool {
        address.count == 42 && address.hasPrefix("0x") && address.dropFirst(2).allSatisfy(\.isHexDigit)
    }

    /// The address in lower case, as the EVM chains' addresses are
    static func normalized(_ address: String) -> String {
        address.lowercased()
    }
}
