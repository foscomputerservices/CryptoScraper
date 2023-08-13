// CryptoChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A representation of a Crypto Block Chain
public protocol CryptoChain: AnyObject, Hashable, Identifiable {
    /// The type of ``CryptoContract`` for this chain
    associatedtype Contract: CryptoContract where Contract.Chain == Self

    /// The type of ``TokenInfo`` for this chain
    associatedtype Info: TokenInfo where Info.Contract == Contract

    associatedtype Scanner: CryptoScanner where Scanner.Contract == Contract

    /// A human-readable string that identifies this block chain
    var userReadableName: String { get }

    /// A collection of information about the tokens supported by the block chain
    var chainTokenInfos: Set<Info> { get }

    /// The ``CryptoContract`` that describes the block chain's primary token
    var mainContract: Contract! { get }

    /// Creates a ``CryptoContract`` for the block chain
    ///
    /// - Parameter address: The unique address that identifies the ``CryptoContract``
    func contract(for address: String) throws -> Contract

    /// Loads the the block chain's ``chainTokenInfos`` from ``CryptoDataAggregator``
    ///
    /// The ``CryptoChain`` will add any tokens from ``tokens`` that correlate
    /// to the block chain.
    ///
    /// - NOTE: Calling this method has the side-effect of modifying ``chainTokenInfos``
    ///
    /// - Parameter dataAggregator: A ``CryptoDataAggregator`` to retrieve token information from
    func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws

    /// Returns the ``TokenInfo`` for the given address
    ///
    /// - Parameter address: The unique address of the token
    func tokenInfo(for address: String) -> Info?

    /// Returns a ``CryptoScanner``, if one has bee configured,
    /// that can be used to retrieve information about various ``CryptoContract``s
    var scanner: Scanner? { get }

    /// Returns a default instance of the ``CryptoChain``
    static var `default`: Self { get }
}

public extension CryptoChain {
    static var zero: ZeroAmountChain { ZeroAmountChain() }

    // MARK: Identifiable Protocol

    var id: String {
        String(reflecting: Contract.self)
    }

    // MARK: Hashable Protocol

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: Equatable Protocol

    /// This function works on 'any CryptoChain' whereas == cannot be used
    func isSame<Other: CryptoChain>(as other: Other) -> Bool {
        guard Other.self == type(of: self) else { return false }

        return (other as! Self) == self
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.mainContract.address == rhs.mainContract.address &&
            lhs.userReadableName == rhs.userReadableName
    }
}
