// ONT.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into ONT+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `ont` namespace, which CAIP's registry does not hold (2026-10-07), so the library owns it until CAIP registers
/// one: Ontology's networks, each by name
public enum ONT {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "ont"

    /// Ontology mainnet, `ont:mainnet`
    public enum Ontology {
        /// The chain's CAIP-2 id
        public static let chainId = ONT.namespace + ":" + "mainnet"

        /// ONT, the chain's coin, at 9 decimals (Ontology's since its upgrade at block 13,920,000), under the
        /// placeholder address CryptoScraper's chain gives it
        public static let ont: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "ont"),
            decimals: 9,
            symbol: AssetSymbol(validating: "ONT")
        )

        /// ONG, the chain's second native coin (its gas), at 18 decimals, under its own placeholder address, its own
        /// declaration (design § 2.5, "Two native coins on one chain")
        public static let ong: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "ong"),
            decimals: 18,
            symbol: AssetSymbol(validating: "ONG")
        )
    }
}
