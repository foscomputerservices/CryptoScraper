// CKB.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into CKB+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `ckb` namespace, which CAIP's registry does not hold (2026-10-07), so the library owns it until CAIP registers
/// one: Nervos CKB's networks, each by name
public enum CKB {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "ckb"

    /// Nervos CKB mainnet, `ckb:mainnet`
    public enum Nervos {
        /// The chain's CAIP-2 id
        public static let chainId = CKB.namespace + ":" + "mainnet"

        /// CKB, the chain's coin, at 8 decimals (shannons), under the placeholder address CryptoScraper's chain gives
        /// it
        public static let ckb: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "ckb"),
            decimals: 8,
            symbol: AssetSymbol(validating: "CKB")
        )
    }
}
