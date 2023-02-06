// CryptoAmount.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct CryptoAmount {
    /// The quantity of the coin in the chain's base units
    public let quantity: Int64

    /// The contract that defines the crypto
    public let contract: CryptoContract
}
