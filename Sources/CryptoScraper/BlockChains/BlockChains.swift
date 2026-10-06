// BlockChains.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
import Synchronization

enum BlockChains {
    // Read and set by whichever domain initializes the library, so it is held behind a `Mutex`.
    private static let initialized = Mutex<Bool>(false)

    /// Initializes all of the supported block chains
    ///
    /// All supported block chains are initialized and loaded with the crypto coin specifications
    /// that are known to the provided ``CryptoDataAggregator``
    static func initializeChains(dataAggregator: CryptoDataAggregator) async throws {
        guard !initialized.withLock({ $0 }) else { throw BlockChainError.alreadyInitialized }

        for chain in knownBlockChains {
            try await chain.loadChainTokens(from: dataAggregator)
        }

        initialized.withLock { $0 = true }
    }

    /// Returns all of the block chains supported by the framework
    static var knownBlockChains: [any CryptoChain] { [
        BitcoinChain.default,
        EthereumChain.default,
        FantomChain.default,
        BinanceSmartChain.default,
        PolygonChain.default,
        OptimismChain.default,
        TronChain.default
    ] }
}

public enum BlockChainError: Error {
    case alreadyInitialized

    public var localizedError: String {
        switch self {
        case .alreadyInitialized:
            return "The library has already been initialized"
        }
    }
}
