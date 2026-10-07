// SOLANA.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into SOLANA+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `solana` namespace of CAIP-2: Solana's clusters, each by the first 32 characters of its genesis hash
public enum SOLANA {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "solana"

    /// Solana mainnet-beta, `solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp`, by the first 32 characters of its genesis hash
    public enum Solana {
        /// The chain's CAIP-2 id
        public static let chainId = SOLANA.namespace + ":" + "5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"

        /// SOL, the chain's coin, at 9 decimals (lamports), under the placeholder address CryptoScraper's chain gives
        /// it
        public static let sol: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "sol"),
            decimals: 9,
            symbol: AssetSymbol(validating: "SOL")
        )
    }
}
