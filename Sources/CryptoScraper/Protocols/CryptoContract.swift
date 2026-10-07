// CryptoContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation

public protocol CryptoContract: Currency, Identifiable, Hashable {
    /// The ``CryptoChain`` on which this contract resides
    associatedtype Chain: CryptoChain where Chain.Contract == Self

    /// Returns the unique *address* of the ``CryptoContract`` in the format
    /// recognized by the block chain
    var address: String { get }

    /// Returns the ``CryptoChain`` that the ``CryptoContract`` belongs to
    var chain: Chain { get }

    /// Returns **true** if the ``CryptoContract`` represents the block chain's coin
    var isChainToken: Bool { get }

    /// Returns **true** if the contract represents a Token known to the chain, but
    /// **not** the chain token
    var isToken: Bool { get }

    /// Returns the ``TokenInfo`` that describes the details of the ``CryptoContract``
    var tokenInfo: Chain.Info? { get }

    /// Initializes the ``CryptoContract``
    init(address: String)
}

public extension CryptoContract {
    // MARK: Default Implementations

    var chain: Chain { .default }

    var tokenInfo: Chain.Info? {
        chain.tokenInfo(for: address)
    }

    var isChainToken: Bool {
        address == chain.mainContract!.address
    }

    var isToken: Bool {
        address != chain.mainContract!.address
    }

    /// Returns **true** if the contracts are equivalent as described by ``TokenInfo``.isEquivalent(to:)
    func isEquivalent(to other: Chain.Contract) -> Bool {
        tokenInfo?.isEquivalent(to: other) ?? false
    }

    /// Whether `other` is an instance of the same asset, on this chain, another chain, or an exchange
    ///
    /// Replaces the `fatalError` of 2023; the one-chain ``isEquivalent(to:)`` through ``TokenInfo`` stays.
    /// Answered by the statement: two contracts are one asset when `registry` puts their instances in one class.
    ///
    /// ```swift
    /// try usdcOnEthereum.isEquivalent(to: usdcOnPolygon, in: registry)     // true
    /// ```
    ///
    /// - Throws: `AssetRegistryError.undeclaredInstance` when either is an instance of no declared asset
    ///
    /// - Precondition: both contracts' `id`s are instance ids, as the bridge `AssetInstance(_:)` requires; a
    ///   ``ZeroAmountChain`` contract's is not
    func isEquivalent<OtherContract: CryptoContract>(to other: OtherContract,
                                                     in registry: AssetRegistry = .shared) throws -> Bool {
        try registry.isEquivalent(AssetInstance(self), AssetInstance(other))
    }

    // MARK: Identifiable Protocol

    var id: String {
        chain.id + ":" + address
    }

    // MARK: Hashable Protocol

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: Equatable Protocol

    /// Compares *other* with *self* for equality
    ///
    /// This function works on 'any CryptoContract' whereas == cannot be used
    func isSame<Other: CryptoContract>(as other: Other) -> Bool {
        guard Other.self == type(of: self) else { return false }

        return (other as! Self) == self
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.address == rhs.address && lhs.chain == rhs.chain
    }
}

// MARK: The bridge (design § 1.5)

public extension AssetInstance {
    /// The instance `contract` names, by its ``CryptoContract/id``: `chain.id + ":" + address`
    ///
    /// One direction of authority: the instance reads the contract's `id`, so when the `id` changes the instance
    /// follows.
    ///
    /// ```swift
    /// AssetInstance(EthereumChain.default.mainContract).id       // "eip155:1:eth"
    /// ```
    ///
    /// - Precondition: the contract's `id` is a CAIP-2-shaped chain id and an address; ``ZeroAmountChain``'s is not,
    ///   and it is never bridged.
    init(_ contract: some CryptoContract) {
        do {
            try self.init(validating: contract.id)
        } catch {
            preconditionFailure("A contract's id is not an instance id: \(contract.id)")
        }
    }
}
