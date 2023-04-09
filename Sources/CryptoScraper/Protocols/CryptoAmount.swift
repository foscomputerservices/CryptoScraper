// CryptoAmount.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

public struct CryptoAmount: Comparable, Codable, Stubbable {
    /// The quantity of the coin in the chain's base units
    public let quantity: UInt128

    /// The contract that defines the crypto
    public let contract: any CryptoContract

    // MARK: Equatable Protocol

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.quantity == rhs.quantity && lhs.contract.isSame(as: rhs.contract)
    }

    // MARK: Comparable Protocol

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.quantity < rhs.quantity
    }
}

public extension CryptoAmount {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.quantity = try container.decode(UInt128.self, forKey: .quantity)
        let chainName = try container.decode(String.self, forKey: .chain)
        guard let chain = chainName.chain else {
            throw CryptoAmountError.unknownChain(name: chainName)
        }
        let address = try container.decode(String.self, forKey: .contractAddress)
        self.contract = try chain.contract(for: address) as (any CryptoContract)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let chain = contract.chain as (any CryptoChain)

        try container.encode(quantity, forKey: .quantity)
        try container.encode(chain.userReadableName, forKey: .chain)
        try container.encode(contract.address, forKey: .contractAddress)
    }

    private enum CodingKeys: String, CodingKey {
        case quantity
        case chain
        case contractAddress
    }
}

public enum CryptoAmountError: Error {
    case unknownChain(name: String)
}

public extension CryptoAmount {
    static func stub() -> Self {
        .init(quantity: 5000, contract: BitcoinContract.stub())
    }
}

private extension String {
    var chain: (any CryptoChain)? {
        BlockChains.knownBlockChains
            .filter { $0.userReadableName == self }
            .first
    }
}
