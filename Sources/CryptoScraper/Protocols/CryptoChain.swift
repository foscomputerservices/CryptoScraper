// CryptoChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public protocol CryptoChain {
    var userReadableName: String { get }
    var scanners: [CryptoScanner] { get }
    var mainContract: CryptoContract! { get }
}
