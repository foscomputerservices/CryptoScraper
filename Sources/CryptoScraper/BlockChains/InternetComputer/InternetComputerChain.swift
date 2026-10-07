// InternetComputerChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Internet Computer, `ICP.InternetComputer.chainId`: its contracts ``InternetComputerContract``, its scanner
/// ``ICPRosetta``
public final class InternetComputerChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = ICP.InternetComputer.chainId

    /// "Internet Computer"
    public let userReadableName: String = "Internet Computer"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<InternetComputerContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// ICP, the chain's coin, under the placeholder address `icp`
    public let mainContract: InternetComputerContract!

    /// The contract at `address`, validated as an account identifier, 64 hex digits, lower-cased (a principal is no
    /// account: it is refused as one), or the coin's placeholder; lower-cased
    ///
    /// - Throws: ``BlockChainError/notAnAccount(_:)`` for a principal, ``BlockChainError/malformedAddress(_:)``
    ///   for any other address
    public func contract(for address: String) throws -> InternetComputerContract {
        if InternetComputerContract.isPrincipal(address) {
            throw BlockChainError.notAnAccount(address)
        }
        let contract = InternetComputerContract(address: address)
        guard contract == mainContract || InternetComputerContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: InternetComputerContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<InternetComputerContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<InternetComputerContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: the Internet Computer's public Rosetta API, `rosetta-api.internetcomputer.org`, keyless
    public let scanner: ICPRosetta = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<InternetComputerContract>? {
        tokens.withLock { $0?[address] }
    }

    static let icpContractAddress = "icp"

    /// The one Internet Computer chain
    public static let `default`: InternetComputerChain = .init()

    private init() {
        self.mainContract = .init(address: Self.icpContractAddress)
    }
}

public extension CryptoChain where Self == InternetComputerChain {
    /// The one Internet Computer chain
    static var internetComputer: InternetComputerChain { .default }
}
