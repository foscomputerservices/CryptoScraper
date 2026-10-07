// ArweaveContract.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A contract on Arweave: a wallet address, 43 characters of base64url; kept as given (base64url is case-sensitive)
public struct ArweaveContract: CryptoContract, Codable, Stubbable, Sendable {
    /// Arweave's ladder: winston to AR, the base unit at exponent 0 and the chain's coin at 12
    public enum Units: String, CurrencyUnits {
        case winston
        case ar

        public static var chainBaseUnits: Self { .winston }
        public static var defaultDisplayUnits: Self { .ar }
    }

    // MARK: CryptoContract Protocol

    public typealias Chain = ArweaveChain

    /// The contract's address
    public let address: String

    /// Initializes the ``ArweaveContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address
    }
}

public extension ArweaveContract {
    /// The contract stub, at a fake address
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension ArweaveContract {
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

public extension ArweaveContract.Units {
    /// Ten to the unit's exponent: 0 for the base unit, 12 for AR
    var divisorFromBase: UInt128 {
        (0..<exponent).reduce(UInt128(1)) { power, _ in power * 10 }
    }

    /// "AR" for the whole unit, "AR(winston)" for the base unit, as Tron's ladder writes it
    var displayIdentifier: String {
        self == .ar
            ? "AR"
            : "AR(\(rawValue))"
    }

    /// The unit's exponent: no fraction in the base unit, 12 digits in AR
    var displayFractionDigits: Int { exponent }
}

private extension ArweaveContract.Units {
    var exponent: Int {
        switch self {
        case .winston: return 0
        case .ar: return 12
        }
    }
}

extension ArweaveContract {
    /// Whether `address` is a wallet address, 43 characters of base64url (the SHA-256 of the wallet's key, unpadded)
    static func isWellFormed(_ address: String) -> Bool {
        address.count == 43 && address.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }
}
