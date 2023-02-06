// Etherscan.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public struct Etherscan: CryptoScanner {
    static let endPiont: URL = .init(string: "https://api.etherscan.io/api")!

    static var apiKey: String {
        guard let key = ProcessInfo.processInfo.environment["ETHER_SCAN_KEY"] else {
            fatalError("ETHER_SCAN_KEY is not set in the environment")
        }

        return key
    }
}

enum EtherscanResponseError: Error {
    case requestFailed
    case invalidAmount
}
