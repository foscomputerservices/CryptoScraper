// CryptoContract.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public protocol CryptoContract {
    var address: String { get }
    var chain: CryptoChain { get }
    var isChainToken: Bool { get }
}
