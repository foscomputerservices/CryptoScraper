// SIA.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into SIA+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `sia` namespace, which CAIP's registry does not hold (2026-10-07), so the library owns it until CAIP registers
/// one: Sia's networks, each by name
public enum SIA {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "sia"

    /// Sia mainnet, `sia:mainnet`
    public enum Sia {
        /// The chain's CAIP-2 id
        public static let chainId = SIA.namespace + ":" + "mainnet"

        /// SC, Siacoin, the chain's coin, at 24 decimals (hastings), under the placeholder address CryptoScraper's
        /// chain gives it
        public static let sc: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "sc"),
            decimals: 24,
            symbol: AssetSymbol(validating: "SC")
        )
    }
}
