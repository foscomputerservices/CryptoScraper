// EXCHANGE.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// Hand-written, never generated: the importer (brief part 9) writes the CAIP-2 namespaces' files and never this one.
// The `exchange` namespace is the library's own (design § 1.3), so its chains are stated here by hand, in the
// generated files' shape.

import FOSFoundation
import Foundation

/// The `exchange` namespace this library owns (design § 1.3): each exchange as a chain of its own, by its id
///
/// An exchange's holdings are its contracts; each plug-in declares them as constants on its exchange chain, and the
/// id of a holding derives from the chain's id and the holding's key, never written by a client.
///
/// ```swift
/// EXCHANGE.Kraken.chainId              // "exchange:kraken"
/// ```
public enum EXCHANGE {
    /// The namespace, the first part of every exchange's id
    public static let namespace = "exchange"

    /// Kraken spot
    public enum Kraken {
        /// The exchange chain's id
        public static let chainId = EXCHANGE.namespace + ":" + "kraken"
    }

    /// Hyperliquid
    public enum Hyperliquid {
        /// The exchange chain's id
        public static let chainId = EXCHANGE.namespace + ":" + "hyperliquid"
    }

    /// Coinbase Advanced Trade
    public enum Coinbase {
        /// The exchange chain's id
        public static let chainId = EXCHANGE.namespace + ":" + "coinbase"
    }

    /// Binance spot
    public enum Binance {
        /// The exchange chain's id
        public static let chainId = EXCHANGE.namespace + ":" + "binance"
    }
}
