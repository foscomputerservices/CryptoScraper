// ISO4217.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// Hand-written, never generated: the importer (Scripts/import-assets.swift) writes the CAIP-2 namespaces' files and
// never this one. The `iso4217` namespace is the library's own (design § 1.4); it states the dollar alone.

import FOSFoundation
import Foundation

/// The `iso4217` namespace this library owns for fiat (design § 1.4): each currency by its ISO 4217 code
public enum ISO4217 {
    /// The namespace, the first part of every fiat's id
    public static let namespace = "iso4217"

    /// The US dollar, at 2 decimals
    public static let usd: AssetDeclaration.Instance = try! AssetDeclaration.Instance(
        instance: AssetInstance(validating: namespace + ":" + "USD"),
        decimals: 2,
        symbol: AssetSymbol(validating: "USD")
    )
}
