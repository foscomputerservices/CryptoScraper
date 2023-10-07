// CryptoContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public protocol CryptoContract: Currency, Identifiable {
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

    func isEquivalent<OtherContract: CryptoContract>(to other: OtherContract) -> Bool {
        if OtherContract.self == Self.self {
            return isEquivalent(to: other as! Self)
        }

        // TODO: Implement isEquivalent for cross-chain comparisons
        fatalError("isEquivalent is NYI cross-chain")
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
