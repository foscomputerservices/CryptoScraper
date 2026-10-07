// COSMOS.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into COSMOS+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `cosmos` namespace of CAIP-2: the Cosmos SDK chains, each by its own chain id
public enum COSMOS {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "cosmos"

    /// The Cosmos Hub, `cosmos:cosmoshub-4`, by its chain id
    public enum CosmosHub {
        /// The chain's CAIP-2 id
        public static let chainId = COSMOS.namespace + ":" + "cosmoshub-4"

        /// ATOM, the chain's coin, at 6 decimals (uatom), under the placeholder address CryptoScraper's chain gives it
        public static let atom: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "atom"),
            decimals: 6,
            symbol: AssetSymbol(validating: "ATOM")
        )
    }

    /// THORChain mainnet, `cosmos:thorchain-1`, by its chain id
    public enum THORChain {
        /// The chain's CAIP-2 id
        public static let chainId = COSMOS.namespace + ":" + "thorchain-1"

        /// RUNE, the chain's coin, at 8 decimals (its count, whose denom is `rune`, the coin's own word), under the
        /// placeholder address CryptoScraper's chain gives it
        public static let rune: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "rune"),
            decimals: 8,
            symbol: AssetSymbol(validating: "RUNE")
        )
    }

    /// Terra mainnet, `cosmos:phoenix-1`, by its chain id (Terra 2; Terra Classic is `columbus-5`)
    public enum Terra {
        /// The chain's CAIP-2 id
        public static let chainId = COSMOS.namespace + ":" + "phoenix-1"

        /// LUNA, the chain's coin, at 6 decimals (uluna), under the placeholder address CryptoScraper's chain gives it
        public static let luna: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "luna"),
            decimals: 6,
            symbol: AssetSymbol(validating: "LUNA")
        )
    }

    /// Fetch.ai mainnet, `cosmos:fetchhub-4`, by its chain id
    public enum FetchAI {
        /// The chain's CAIP-2 id
        public static let chainId = COSMOS.namespace + ":" + "fetchhub-4"

        /// FET, the chain's coin, at 18 decimals (afet), under the placeholder address CryptoScraper's chain gives it;
        /// FET also trades as a token on Ethereum, a declaration of its own
        public static let fet: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "fet"),
            decimals: 18,
            symbol: AssetSymbol(validating: "FET")
        )
    }
}
