// TokenInfo.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A store of information describing a block chain token
public protocol TokenInfo: Codable, Hashable, Identifiable {
    associatedtype Contract: CryptoContract

    /// The ``CryptoContract`` of the token
    var contractAddress: Contract { get }

    /// A set of contracts that logically represent the same token
    var equivalentContracts: Set<Contract> { get }

    /// A user-readable name for the token
    var tokenName: String { get }

    /// A short symbol that represents the token
    var symbol: String { get }

    /// An image the represents the token
    var imageURL: URL? { get }

    var tokenType: String? { get }
    var totalSupply: Amount<Contract>? { get }
    var blueCheckmark: Bool? { get }
    var description: String? { get }
    var website: URL? { get }
    var email: String? { get }
    var blog: URL? { get }
    var reddit: URL? { get }
    var slack: String? { get }
    var facebook: URL? { get }
    var twitter: URL? { get }
    var gitHub: URL? { get }
    var telegram: URL? { get }
    var wechat: URL? { get }
    var linkedin: URL? { get }
    var discord: URL? { get }
    var whitepaper: URL? { get }

    /// Returns **true** if the contracts are equivalent
    ///
    /// Two ``CryptoContract``s are equivalent if they
    /// match in the ``equivalentContracts`` set.
    ///
    /// - NOTE: There is a default implementation provided.
    func isEquivalent(to other: Contract) -> Bool
}

public extension TokenInfo {
    var equivalentContracts: Set<Contract> { [] }
    var imageURL: URL? { nil }
    var tokenType: String? { nil }
    var totalSupply: Amount<Contract>? { nil }
    var blueCheckmark: Bool? { nil }
    var description: String? { nil }
    var website: URL? { nil }
    var email: String? { nil }
    var blog: URL? { nil }
    var reddit: URL? { nil }
    var slack: String? { nil }
    var facebook: URL? { nil }
    var twitter: URL? { nil }
    var gitHub: URL? { nil }
    var telegram: URL? { nil }
    var wechat: URL? { nil }
    var linkedin: URL? { nil }
    var discord: URL? { nil }
    var whitepaper: URL? { nil }

    func isEquivalent(to other: Contract) -> Bool {
        other.isSame(as: contractAddress) || equivalentContracts.contains { equiv in equiv.isSame(as: other) }
    }

    // MARK: Identifiable Protocol

    var id: String {
        contractAddress.id
    }

    // MARK: Hashable Protocol

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: Equatable Protocol

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.contractAddress == rhs.contractAddress
    }
}
