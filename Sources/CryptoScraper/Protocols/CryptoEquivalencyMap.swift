// CryptoEquivalencyMap.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

public struct CryptoEquivalencyMap {
    private let lookup: (any CryptoContract) -> [any CryptoContract]?

    public func equivalentContracts(to contract: any CryptoContract) -> [any CryptoContract]? {
        lookup(contract)
    }

    init(map: [String: [any CryptoContract]]) {
        self.lookup = { contract in
            // TODO: Probably need to index this as some point
            for list in map.values {
                if list.contains(where: { $0.isSame(as: contract) }) {
                    return list
                }
            }

            return nil
        }
    }
}

// MARK: The map, answered by the statement (design § 2.6)

public extension CryptoEquivalencyMap {
    /// Your map, one entry per declared asset, its instances as your contracts on your chains and exchanges
    ///
    /// Read from `registry` when asked: ``equivalentContracts(to:)`` of a contract is every instance of its asset
    /// that ``BlockChains/contract(of:)`` knows a chain for, the contract's own included; `nil` when the contract is
    /// an instance of no declared asset.
    ///
    /// - Precondition: the contract's `id` is an instance id, as the bridge `AssetInstance(_:)` requires; a
    ///   ``ZeroAmountChain`` contract's is not
    ///
    /// ```swift
    /// CryptoEquivalencyMap(.shared).equivalentContracts(to: usdcOnPolygon)?.first?.id
    /// // "eip155:1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48": USD Coin's home, Ethereum's contract, first
    /// ```
    init(_ registry: AssetRegistry) {
        self.lookup = { contract in
            guard
                let asset = try? registry.asset(of: AssetInstance(contract)),
                let declaration = try? registry.declaration(of: asset)
            else {
                return nil
            }

            return declaration.instances.compactMap { BlockChains.contract(of: $0.instance) }
        }
    }
}
