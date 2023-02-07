// Etherscan+Tokens.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension Etherscan {
    /// Returns balance of the given token for the given address
    ///
    /// - Parameters:
    ///   - contract: The contract of the token to query
    ///   - address: The contract address that holds the token
    func getBalance(forToken contract: CryptoContract, forAccount account: CryptoContract) async throws -> CryptoAmount {
        // Cannot retrieve ETH contract, but retrieve ETH balance
        if contract.isChainToken {
            return try await getBalance(forAccount: account)
        } else {
            let response: TokenBalanceResponse = try await Self.endPiont.appending(
                queryItems: TokenBalanceResponse.httpQuery(forToken: contract, address: account, apiKey: Self.apiKey)
            ).fetch()

            return try response.cryptoBalance(forToken: contract, ethContract: account.chain.mainContract)
        }
    }

    /// Returns token information
    ///
    /// - NOTE: This API is **PRO** only and rate limited to 2 calls/sec
    ///
    /// - Parameters:
    ///   - contract: The contract of the token to query
    func getInfo(forToken contract: CryptoContract) async throws -> CryptoInfo {
        let response: TokenInfoResponse = try await Self.endPiont.appending(
            queryItems: TokenInfoResponse.httpQuery(forToken: contract, apiKey: Self.apiKey)
        ).fetch()

        return try response.cryptoInfo()
    }
}

private struct TokenBalanceResponse: Decodable {
    let status: String
    let message: String
    let result: String

    var success: Bool {
        status == "1" || message == "OK"
    }

    func cryptoBalance(forToken: CryptoContract, ethContract: CryptoContract) throws -> CryptoAmount {
        guard success else {
            throw EtherscanResponseError.requestFailed(result)
        }
        guard let amount = Int64(result) else {
            throw EtherscanResponseError.invalidAmount
        }

        return .init(quantity: amount, contract: forToken)
    }

    // https://docs.etherscan.io/api-endpoints/tokens#get-erc20-token-account-balance-for-tokencontractaddress
    static func httpQuery(forToken contract: CryptoContract, address: CryptoContract, apiKey: String) -> [URLQueryItem] { [
        .init(name: "module", value: "account"),
        .init(name: "action", value: "tokenbalance"),
        .init(name: "contractaddress", value: contract.address),
        .init(name: "address", value: address.address),
        .init(name: "tag", value: "latest"),
        .init(name: "apiKey", value: apiKey)
    ] }
}

private struct TokenInfoResponse: Decodable {
    let status: String
    let message: String
    let result: [TokenInfo] // It says array in the spec 🤷‍♂️

    var success: Bool {
        status == "1" || message == "OK"
    }

    func cryptoInfo() throws -> CryptoInfo {
        guard success, let tokenInfo = result.first else {
            throw EtherscanResponseError.requestFailed("<< Unknown Error >>")
        }

        return tokenInfo.cryptoInfo()
    }

    // https://docs.etherscan.io/api-endpoints/tokens#get-token-info-by-contractaddress
    static func httpQuery(forToken contract: CryptoContract, apiKey: String) -> [URLQueryItem] { [
        .init(name: "module", value: "token"),
        .init(name: "action", value: "tokeninfo"),
        .init(name: "contractaddress", value: contract.address),
        .init(name: "apiKey", value: apiKey)
    ] }
}

private struct TokenInfo: Decodable {
    let contractAddress: String
    let tokenName: String
    let symbol: String
    let divisor: String
    let tokenType: String
    let totalSupply: String
    let blueCheckmark: String
    let description: String
    let website: String
    let email: String
    let blog: String
    let reddit: String
    let slack: String
    let facebook: String
    let twitter: String
    let bitcointalk: String
    let gitHub: String
    let telegram: String
    let wechat: String
    let linkedin: String
    let discord: String
    let whitepaper: String
    let tokenPriceUSD: String

    func cryptoInfo() -> CryptoInfo {
        MappedInfo(tokenInfo: self)
    }

    private struct MappedInfo: CryptoInfo {
        // MARK: CryptoTransaction

        let contractAddress: CryptoContract
        let tokenName: String
        let symbol: String
        let tokenType: String
        let totalSupply: CryptoAmount?
        let blueCheckmark: Bool?
        let description: String?
        let website: URL?
        let email: String?
        let blog: URL?
        let reddit: URL?
        let slack: String?
        let facebook: URL?
        let twitter: URL?
        let gitHub: URL?
        let telegram: URL?
        let wechat: URL?
        let linkedin: URL?
        let discord: URL?
        let whitepaper: URL?

        init(tokenInfo: TokenInfo) {
            let contract = EthereumContract(address: tokenInfo.contractAddress)
            self.contractAddress = contract
            self.tokenName = tokenInfo.tokenName
            self.symbol = tokenInfo.symbol
            self.tokenType = tokenInfo.tokenType

            let totalSupply = Int64(tokenInfo.totalSupply)
            self.totalSupply = totalSupply == nil ? nil : .init(quantity: totalSupply!, contract: contract)
            self.blueCheckmark = Bool(tokenInfo.blueCheckmark)
            self.description = tokenInfo.description
            self.website = URL(string: tokenInfo.website)
            self.email = tokenInfo.email.isEmpty ? nil : tokenInfo.email
            self.blog = URL(string: tokenInfo.website)
            self.reddit = URL(string: tokenInfo.website)
            self.slack = tokenInfo.slack.isEmpty ? nil : tokenInfo.slack
            self.facebook = URL(string: tokenInfo.facebook)
            self.twitter = URL(string: tokenInfo.twitter)
            self.gitHub = URL(string: tokenInfo.gitHub)
            self.telegram = URL(string: tokenInfo.telegram)
            self.wechat = URL(string: tokenInfo.wechat)
            self.linkedin = URL(string: tokenInfo.linkedin)
            self.discord = URL(string: tokenInfo.discord)
            self.whitepaper = URL(string: tokenInfo.whitepaper)
        }
    }
}
