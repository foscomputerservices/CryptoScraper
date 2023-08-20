// EthereumContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public struct EthereumContract: CryptoContract, Codable, Stubbable {
    public typealias Chain = EthereumChain

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
        numberFormatter.currencyCode = "ETH"

        return numberFormatter
    }

    // MARK: CryptoContract Protocol

    public let address: String
    public var chain: Chain { Chain.default }
    public var isChainToken: Bool {
        address == EthereumChain.ethContractAddress
    }

    /// Initializes the ``EthereumContract``
    ///
    /// - Parameters:
    ///   - address: The address of the contract
    public init(address: String) {
        self.address = address.lowercased()
    }
}

public extension EthereumContract {
    // MARK: Codable Protocol

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

public extension EthereumContract {
    static func stub() -> Self {
        .init(address: "a-fake-contract-address")
    }
}

public extension EthereumContract.Units {
    var divisorFromBase: UInt128 {
        UInt128(pow(10, Double(exponent)))
    }

    var displayIdentifier: String {
        self == .ether
            ? "ETH"
            : rawValue
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

private extension EthereumContract.Units {
    var exponent: Int {
        switch self {
        case .wei: return 1
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
