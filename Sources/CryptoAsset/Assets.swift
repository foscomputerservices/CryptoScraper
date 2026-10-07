// Assets.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//
// Hand-written, never generated: the enum the importer's `Assets+Imported.swift` extends.

import FOSFoundation
import Foundation

/// The asset classes the importer found (design § 2.7), each a home instance and the instances the reference lists on
/// other chains
///
/// Each constant is an ``AssetDeclaration`` written by `Scripts/import-assets.swift` into `Assets+Imported.swift`, named
/// from CoinGecko's id for the coin in lowerCamel, never from its symbol: CoinGecko's `usd-coin` is ``usdCoin``. Its
/// home comes first, on the chain CoinGecko marks as the coin's own; its other instances follow, one per admitted
/// chain the coin has a contract on. Together they are the equivalence map written out as code. A chain's own coin is
/// its conformer's, never one of these.
///
/// ```swift
/// Assets.usdCoin.asset == .usdc                   // true: the class USD Coin's home keys
/// Assets.usdCoin.instances.map(\.instance.id)     // Ethereum's first, then each other admitted chain's
/// ```
public enum Assets {}
