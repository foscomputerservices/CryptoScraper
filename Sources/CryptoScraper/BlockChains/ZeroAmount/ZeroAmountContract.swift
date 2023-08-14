// ZeroAmountContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct ZeroAmountContract: CryptoContract {
    public let address: String
    public let isChainToken: Bool
    public let isToken: Bool
    public let chain: ZeroAmountChain

    public static var zero: Self { .init(address: "") }

    public init(address: String) {
        self.address = "0x0000000000000000000000000000000000000000"
        self.isChainToken = true
        self.isToken = false
        self.chain = ZeroAmountChain()
    }

    public init(from decoder: Decoder) throws {
        self = .zero
    }

    public func encode(to encoder: Encoder) throws {
        // N/A
    }
}
