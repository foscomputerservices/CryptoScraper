// VECHAIN.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into VECHAIN+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `vechain` namespace of CAIP-2: VeChainThor's networks, each by the last 16 bytes of its genesis block id
public enum VECHAIN {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "vechain"

    /// VeChainThor mainnet, `vechain:b1ac3413d346d43539627e6be7ec1b4a`
    public enum VeChain {
        /// The chain's CAIP-2 id
        public static let chainId = VECHAIN.namespace + ":" + "b1ac3413d346d43539627e6be7ec1b4a"

        /// VET, the chain's coin, at 18 decimals (wei), under the placeholder address CryptoScraper's chain gives it
        public static let vet: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "vet"),
            decimals: 18,
            symbol: AssetSymbol(validating: "VET")
        )

        /// VTHO, the chain's second native coin (its energy), at 18 decimals, under its own placeholder address, its
        /// own
        /// declaration (design § 2.5, "Two native coins on one chain")
        public static let vtho: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "vtho"),
            decimals: 18,
            symbol: AssetSymbol(validating: "VTHO")
        )
    }
}
