// OptimismContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public struct OptimismContract: CryptoContract, Codable, Stubbable {
    public typealias Chain = OptimismChain

    // https://etherscan.io/unitconverter
    public enum Units: String, CurrencyUnits {
        case wei
        case kwei
        case mwei
        case gwei
        case szabo
        case finney
        case ether
        case kether
        case mether
        case gether
        case tether

        public static var chainBaseUnits: Self { .wei }
        public static var defaultDisplayUnits: Self { .ether }
    }

    // MARK: CurrencyFormatter

    public var formatter: Formatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = "OP"

        return numberFormatter
    }

    // MARK: CryptoContract Protocol

    public let address: String
    public var chain: Chain { Chain.default }
    public var isChainToken: Bool {
        address == OptimismChain.opContractAddress
    }

    /// Initializes the ``OptimismContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address.lowercased()
    }
}

public extension OptimismContract {
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

public extension OptimismContract {
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension OptimismContract.Units {
    var divisorFromBase: UInt128 {
        let exponent: Double

        switch self {
        case .wei: exponent = 1
        case .kwei: exponent = 3
        case .mwei: exponent = 6
        case .gwei: exponent = 9
        case .szabo: exponent = 12
        case .finney: exponent = 15
        case .ether: exponent = 18
        case .kether: exponent = 21
        case .mether: exponent = 24
        case .gether: exponent = 27
        case .tether: exponent = 30
        }

        return UInt128(pow(10, exponent))
    }

    var displayIdentifier: String {
        self == .ether
            ? "OP"
            : "OP(\(rawValue))"
    }

    var displayFractionDigits: Int {
        switch self {
        case .wei: return 0
        case .kwei: return 3
        case .mwei: return 6
        case .gwei: return 9
        case .szabo: return 12
        case .finney: return 15
        case .ether: return 18
        case .kether: return 21
        case .mether: return 24
        case .gether: return 27
        case .tether: return 30
        }
    }
}
