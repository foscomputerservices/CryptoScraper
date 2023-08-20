// EthereumScanner+Tokens.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension EthereumScanner {
    /// Returns balance of the given token for the given address
    ///
    /// - Parameters:
    ///   - contract: The contract of the token to query
    ///   - address: The contract address that holds the token
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        // Cannot retrieve ETH contract, but retrieve ETH balance
        if contract.isChainToken {
            return try await getBalance(forAccount: account)
        } else {
            let response: TokenBalanceResponse = try await Self.endPoint.appending(
                queryItems: TokenBalanceResponse.httpQuery(forToken: contract, address: account, apiKey: Self.requireApiKey())
            ).fetch()

            return try response.cryptoBalance(
                forToken: contract,
                ethContract: account.chain.mainContract
            )
        }
    }

    /// Returns token information
    ///
    /// - NOTE: This API is **PRO** only and rate limited to 2 calls/sec
    ///
    /// - Parameters:
    ///   - contract: The contract of the token to query
    func getInfo(forToken contract: EthereumContract) async throws -> SimpleTokenInfo<EthereumContract> {
        let response: TokenInfoResponse = try await Self.endPoint.appending(
            queryItems: TokenInfoResponse.httpQuery(forToken: contract, apiKey: Self.requireApiKey())
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

    func cryptoBalance<C: CryptoContract>(forToken: C, ethContract: C) throws -> Amount<C> {
        guard success else {
            throw EthereumScannerResponseError.requestFailed(result)
        }
        guard let amount = UInt128(result) else {
            throw EthereumScannerResponseError.invalidAmount
        }

        return .init(quantity: amount, currency: forToken)
    }

    // https://docs.etherscan.io/api-endpoints/tokens#get-erc20-token-account-balance-for-tokencontractaddress
    static func httpQuery(forToken contract: any CryptoContract, address: any CryptoContract, apiKey: String) -> [URLQueryItem] { [
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
    let result: [EthereumTokenInfo] // It says array in the spec 🤷‍♂️

    var success: Bool {
        status == "1" || message == "OK"
    }

    func cryptoInfo() throws -> SimpleTokenInfo<EthereumContract> {
        guard success, let tokenInfo = result.first else {
            throw EthereumScannerResponseError.requestFailed("<< Unknown Error >>")
        }

        return tokenInfo.cryptoInfo()
    }

    // https://docs.etherscan.io/api-endpoints/tokens#get-token-info-by-contractaddress
    static func httpQuery(forToken contract: any CryptoContract, apiKey: String) -> [URLQueryItem] { [
        .init(name: "module", value: "token"),
        .init(name: "action", value: "tokeninfo"),
        .init(name: "contractaddress", value: contract.address),
        .init(name: "apiKey", value: apiKey)
    ] }
}

private struct EthereumTokenInfo: Decodable {
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

    func cryptoInfo() -> SimpleTokenInfo<EthereumContract> {
        SimpleTokenInfo(tokenInfo: self)
    }
}

private extension SimpleTokenInfo where Contract == EthereumContract {
    init(tokenInfo: EthereumTokenInfo) {
        self.contractAddress = EthereumContract(address: tokenInfo.contractAddress)
        self.equivalentContracts = .init()
        self.tokenName = tokenInfo.tokenName
        self.symbol = tokenInfo.symbol
        self.imageURL = nil
        self.tokenType = tokenInfo.tokenType

        let totalSupply = UInt128(tokenInfo.totalSupply)
        self.totalSupply = totalSupply == nil
            ? nil
            : .init(
                quantity: totalSupply!,
                currency: EthereumChain.default.mainContract
            )
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
