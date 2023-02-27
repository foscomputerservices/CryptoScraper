// CryptoInfo.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public protocol CryptoInfo {
    var contractAddress: CryptoContract { get }
    var tokenName: String { get }
    var symbol: String { get }
    var imageURL: URL? { get }
    var tokenType: String? { get }
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

public extension CryptoInfo {
    var imageURL: URL? { nil }
    var tokenType: String? { nil }
    var totalSupply: CryptoAmount? { nil }
    var blueCheckmark: Bool? { nil }
    var description: String? { nil }
    var website: URL? { nil }
    var email: String? { nil }
    var blog: URL? { nil }
    var reddit: URL? { nil }
    var slack: String? { nil }
    var facebook: URL? { nil }
    var twitter: URL? { nil }
    var gitHub: URL? { nil }
    var telegram: URL? { nil }
    var wechat: URL? { nil }
    var linkedin: URL? { nil }
    var discord: URL? { nil }
    var whitepaper: URL? { nil }
}
