// TokenInfo.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
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
    var aggregatorId: String? { get }

    /// Returns **true** if the contracts are equivalent
    ///
    /// Two ``CryptoContract``s are equivalent if they
    /// match in the ``equivalentContracts`` set, or if `other` is the token's own ``contractAddress``.
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
    var aggregatorId: String? { nil }

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

// MARK: The bridge (design § 2.1)

public extension AssetDeclaration.Instance {
    /// An on-chain instance from what the reference loaded into its chain, with the decimals its scanner states
    ///
    /// The instance is the token's contract, by its ``CryptoContract/id``; the symbol is the token's
    /// ``TokenInfo/symbol``, upper-cased. The decimals are never read from the reference.
    ///
    /// ```swift
    /// let usdc = try AssetDeclaration.Instance(EthereumChain.default.tokenInfo(for: address)!, decimals: 6)
    /// ```
    ///
    /// - Throws: `AssetError.malformedIdentity` when the contract's `id` is not an instance id;
    ///   `AssetError.decimalsOutOfRange` outside 0 through 30; `AssetSymbolError` for a symbol that is not one
    init<Info: TokenInfo>(_ info: Info, decimals: Int) throws {
        try self.init(
            instance: AssetInstance(validating: info.contractAddress.id),
            decimals: decimals,
            symbol: AssetSymbol(validating: info.symbol)
        )
    }
}
