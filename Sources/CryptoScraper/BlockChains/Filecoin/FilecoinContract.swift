// FilecoinContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Filecoin: a mainnet address, `f0` and an actor id, `f1`, `f2` or `f3` and lower-case base32, or a
/// delegated `f4` address (`f410f…`); kept as given
public struct FilecoinContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Filecoin's ladder: attoFIL to FIL, the base unit at exponent 0 and the chain's coin at 18
    public enum Units: String, CurrencyUnits {
        case attofil
        case fil

        public static var chainBaseUnits: Self { .attofil }
        public static var defaultDisplayUnits: Self { .fil }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = FilecoinChain

    /// The contract's address
    public let address: String

    /// Initializes the ``FilecoinContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension FilecoinContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension FilecoinContract {
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

public extension FilecoinContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 18 for FIL
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "FIL" for the whole unit, "FIL(attofil)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .fil
            ? "FIL"
            : "FIL(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 18 digits in FIL
    var displayFractionDigits: Int { exponent }
}

private extension FilecoinContract.Units {
    var exponent: Int {
        switch self {
        case .attofil: return 0
        case .fil: return 18
        }
    }
}

extension FilecoinContract {
    /// Whether `address` is a Filecoin mainnet address: `f0` and an actor id; `f1` or `f2` and 39, `f3` and 84
    /// characters of lower-case base32; or `f4`, a namespace actor id, `f` and lower-case base32 (`f410f…`)
    ///
    /// The address's checksum is not verified.
    static func isWellFormed(_ address: String) -> Bool {
        guard address.hasPrefix("f"), address.count >= 3 else {
            return false
        }
        let protocolDigit = address.dropFirst().first!
        let payload = address.dropFirst(2)
        switch protocolDigit {
        case "0":
            return payload.count <= 20 && payload.allSatisfy { $0.isASCII && $0.isNumber }
        case "1", "2":
            return payload.count == 39 && payload.allSatisfy { base32.contains($0) }
        case "3":
            return payload.count == 84 && payload.allSatisfy { base32.contains($0) }
        case "4":
            guard let separator = payload.firstIndex(of: "f") else { return false }
            let namespace = payload[..<separator]
            let subaddress = payload[payload.index(after: separator)...]
            return !namespace.isEmpty && namespace.allSatisfy { $0.isASCII && $0.isNumber }
                && !subaddress.isEmpty && subaddress.allSatisfy { base32.contains($0) }
        default:
            return false
        }
    }

    private static let base32 = Set("abcdefghijklmnopqrstuvwxyz234567")
}
