// OntologyChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// Ontology, `ONT.Ontology.chainId`: its contracts ``OntologyContract``, its scanner ``OntologyExplorer``
public final class OntologyChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = ONT.Ontology.chainId

    /// "Ontology"
    public let userReadableName: String = "Ontology"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<OntologyContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// ONT, the chain's coin, under the placeholder address `ont`
    public let mainContract: OntologyContract!

    /// The contract at `address`, validated as an address, `A` and 33 more characters of base58 decoding to version 23
    /// (0x17) and a 20-byte hash, or an OEP-4 contract's hash, 40 lower-case hex digits, or one of the two coins'
    /// placeholders; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> OntologyContract {
        let contract = OntologyContract(address: address)
        guard contract == mainContract || contract.address == Self.ongContractAddress || OntologyContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: OntologyContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<OntologyContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<OntologyContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: Ontology's public explorer API, `explorer.ont.io/v2`, keyless
    public let scanner: OntologyExplorer = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<OntologyContract>? {
        tokens.withLock { $0?[address] }
    }

    static let ontContractAddress = "ont"

    static let ongContractAddress = "ong"

    /// The one Ontology chain
    public static let `default`: OntologyChain = .init()

    private init() {
        self.mainContract = .init(address: Self.ontContractAddress)
    }
}

public extension CryptoChain where Self == OntologyChain {
    /// The one Ontology chain
    static var ontology: OntologyChain { .default }
}
