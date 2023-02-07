// CryptoChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public protocol CryptoChain: AnyObject {
    var userReadableName: String { get }
    var scanners: [CryptoScanner] { get }
    var chainCryptos: [CryptoInfo] { get }
    var mainContract: CryptoContract! { get }
    func contract(for address: String) throws -> CryptoContract
    func loadChainCryptos(from coins: [CryptoInfo])
}
