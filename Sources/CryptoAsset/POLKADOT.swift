// POLKADOT.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into POLKADOT+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `polkadot` namespace of CAIP-2: the chains of the Polkadot Host protocol, each by the first 32 hex digits of its
/// genesis block's hash
public enum POLKADOT {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "polkadot"

    /// The Polkadot relay chain, by the first 32 hex digits of its genesis block's hash, as the polkadot namespace
    /// lists it
    public enum Polkadot {
        /// The chain's CAIP-2 id
        public static let chainId = POLKADOT.namespace + ":" + "91b171bb158e2d3848fa23a9f1c25182"

        /// DOT, the chain's coin, at 10 decimals (planck), under the placeholder address CryptoScraper's chain gives it
        public static let dot: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "dot"),
            decimals: 10,
            symbol: AssetSymbol(validating: "DOT")
        )
    }

    /// The Kusama relay chain, by the first 32 hex digits of its genesis block's hash, as the polkadot namespace lists
    /// it
    public enum Kusama {
        /// The chain's CAIP-2 id
        public static let chainId = POLKADOT.namespace + ":" + "b0a8d493285c2df73290dfb7e61f870f"

        /// KSM, the chain's coin, at 12 decimals (planck), under the placeholder address CryptoScraper's chain gives it
        public static let ksm: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "ksm"),
            decimals: 12,
            symbol: AssetSymbol(validating: "KSM")
        )
    }

    /// The Enjin Relaychain, by the first 32 hex digits of its genesis block's hash (read from its own node 2026-10-07;
    /// the polkadot namespace's list does not hold it)
    public enum Enjin {
        /// The chain's CAIP-2 id
        public static let chainId = POLKADOT.namespace + ":" + "d8761d3c88f26dc12875c00d3165f7d6"

        /// ENJ, the chain's coin, at 18 decimals (planck), under the placeholder address CryptoScraper's chain gives
        /// it; ENJ also trades as a token on Ethereum, a declaration of its own
        public static let enj: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "enj"),
            decimals: 18,
            symbol: AssetSymbol(validating: "ENJ")
        )
    }
}
