// ICP.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
//
// Hand-written: the namespace, its chains' ids and their own coins. The contracts the importer finds are generated
// into ICP+Imported.swift by Scripts/import-assets.swift and never edited by hand.

import FOSFoundation
import Foundation

/// The `icp` namespace, which CAIP's registry does not hold (2026-10-07), so the library owns it until CAIP registers
/// one: the Internet Computer's networks, each by name
public enum ICP {
    /// The namespace, the first part of every chain id in it
    public static let namespace = "icp"

    /// The Internet Computer's mainnet, `icp:mainnet`
    public enum InternetComputer {
        /// The chain's CAIP-2 id
        public static let chainId = ICP.namespace + ":" + "mainnet"

        /// ICP, the chain's coin, at 8 decimals (e8s), under the placeholder address CryptoScraper's chain gives it
        public static let icp: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
            instance: AssetInstance(validating: chainId + ":" + "icp"),
            decimals: 8,
            symbol: AssetSymbol(validating: "ICP")
        )
    }
}
