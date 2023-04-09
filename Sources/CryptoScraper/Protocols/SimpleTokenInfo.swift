// SimpleTokenInfo.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

/// A straightforward implementation of ``TokenInfo``
public struct SimpleTokenInfo<Contract: CryptoContract>: TokenInfo {
    public let contractAddress: Contract
    public let equivalentContracts: Set<Contract>
    public let tokenName: String
    public let symbol: String
    public let imageURL: URL?
    public let tokenType: String?
    public let totalSupply: CryptoAmount?
    public let blueCheckmark: Bool?
    public let description: String?
    public let website: URL?
    public let email: String?
    public let blog: URL?
    public let reddit: URL?
    public let slack: String?
    public let facebook: URL?
    public let twitter: URL?
    public let gitHub: URL?
    public let telegram: URL?
    public let wechat: URL?
    public let linkedin: URL?
    public let discord: URL?
    public let whitepaper: URL?

    public init(contractAddress: Contract, equivalentContracts: Set<Contract>, tokenName: String, symbol: String, imageURL: URL? = nil, tokenType: String? = nil, totalSupply: CryptoAmount? = nil, blueCheckmark: Bool? = nil, description: String? = nil, website: URL? = nil, email: String? = nil, blog: URL? = nil, reddit: URL? = nil, slack: String? = nil, facebook: URL? = nil, twitter: URL? = nil, gitHub: URL? = nil, telegram: URL? = nil, wechat: URL? = nil, linkedin: URL? = nil, discord: URL? = nil, whitepaper: URL? = nil) {
        self.contractAddress = contractAddress
        self.equivalentContracts = equivalentContracts
        self.tokenName = tokenName
        self.symbol = symbol
        self.imageURL = imageURL
        self.tokenType = tokenType
        self.totalSupply = totalSupply
        self.blueCheckmark = blueCheckmark
        self.description = description
        self.website = website
        self.email = email
        self.blog = blog
        self.reddit = reddit
        self.slack = slack
        self.facebook = facebook
        self.twitter = twitter
        self.gitHub = gitHub
        self.telegram = telegram
        self.wechat = wechat
        self.linkedin = linkedin
        self.discord = discord
        self.whitepaper = whitepaper
    }
}

public extension SimpleTokenInfo {
    init<Info: TokenInfo>(tokenInfo: Info) where Contract == Info.Contract {
        self.init(
            contractAddress: tokenInfo.contractAddress,
            equivalentContracts: tokenInfo.equivalentContracts,
            tokenName: tokenInfo.tokenName,
            symbol: tokenInfo.symbol,
            imageURL: tokenInfo.imageURL,
            tokenType: tokenInfo.tokenType,
            totalSupply: tokenInfo.totalSupply,
            blueCheckmark: tokenInfo.blueCheckmark,
            description: tokenInfo.description,
            website: tokenInfo.website,
            email: tokenInfo.email,
            blog: tokenInfo.blog,
            reddit: tokenInfo.reddit,
            slack: tokenInfo.slack,
            facebook: tokenInfo.facebook,
            twitter: tokenInfo.twitter,
            gitHub: tokenInfo.gitHub,
            telegram: tokenInfo.telegram,
            wechat: tokenInfo.wechat,
            linkedin: tokenInfo.linkedin,
            discord: tokenInfo.discord,
            whitepaper: tokenInfo.whitepaper
        )
    }
}
