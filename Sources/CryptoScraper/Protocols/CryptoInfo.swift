// CryptoInfo.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public protocol CryptoInfo {
    var contractAddress: CryptoContract { get }
    var tokenName: String { get }
    var symbol: String { get }
    var tokenType: String { get }
    var totalSupply: CryptoAmount? { get }
    var blueCheckmark: Bool? { get }
    var description: String? { get }
    var website: URL? { get }
    var email: String? { get }
    var blog: URL? { get }
    var reddit: URL? { get }
    var slack: String? { get }
    var facebook: URL? { get }
    var twitter: URL? { get }
    var gitHub: URL? { get }
    var telegram: URL? { get }
    var wechat: URL? { get }
    var linkedin: URL? { get }
    var discord: URL? { get }
    var whitepaper: URL? { get }
}
