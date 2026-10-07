// EthereumScanner+Tokens.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension EthereumScanner {
    /// Returns balance of the given token for the given account; for the chain's own coin, the account's balance
    /// (``getBalance(forAccount:)``)
    ///
    /// - Parameters:
    ///   - contract: The contract of the token to query
    ///   - account: The contract address that holds the token
    ///
    /// - Throws: ``EthereumScannerResponseError/missingApiKey(_:)`` until the key is set,
    ///   ``EthereumScannerResponseError/requestFailed(_:)`` when V2 refuses, and
    ///   ``EthereumScannerResponseError/invalidAmount`` when the answer is not an integer
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        // Cannot retrieve ETH contract, but retrieve ETH balance
        if contract.isChainToken {
            return try await getBalance(forAccount: account)
        } else {
            let response: TokenBalanceResponse = try await Self.requestURL(TokenBalanceResponse.httpQuery(forToken: contract, address: account)).fetch()

            return try response.cryptoBalance(
                forToken: contract,
                ethContract: account.chain.mainContract
            )
        }
    }

    /// Returns token information, its ``SimpleTokenInfo/decimals`` the chain's own, from V2's `divisor`: the
    /// scanner is the oracle of a token's decimals (design § 2.5, § 4.1)
    ///
    /// - NOTE: This API is **PRO** only and rate limited to 2 calls/sec: V2 answers a free key "Sorry, it looks like
    ///   you are trying to access an API Pro endpoint", thrown as ``EthereumScannerResponseError/requestFailed(_:)``
    ///
    /// - Parameters:
    ///   - contract: The contract of the token to query
    func getInfo(forToken contract: Contract) async throws -> SimpleTokenInfo<Contract> {
        let response: TokenInfoResponse = try await Self.requestURL(TokenInfoResponse.httpQuery(forToken: contract))
            .fetch()

        return try response.cryptoInfo(on: contract.chain.mainContract)
    }
}

struct TokenBalanceResponse: Decodable {
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
        guard let amount = Int128(result) else {
            throw EthereumScannerResponseError.invalidAmount
        }

        return .init(quantity: amount, currency: forToken)
    }

    // https://docs.etherscan.io/api-endpoints/tokens#get-erc20-token-account-balance-for-tokencontractaddress
    static func httpQuery(forToken contract: any CryptoContract, address: any CryptoContract) -> [URLQueryItem] { [
        .init(name: "module", value: "account"),
        .init(name: "action", value: "tokenbalance"),
        .init(name: "contractaddress", value: contract.address),
        .init(name: "address", value: address.address),
        .init(name: "tag", value: "latest")
    ] }
}

struct TokenInfoResponse: Decodable {
    let status: String
    let message: String
    let result: [EthereumTokenInfo] // It says array in the spec 🤷‍♂️

    // V2 refuses in the `result` itself, as text ("Sorry, it looks like you are trying to access an API Pro
    // endpoint..."), where an answer holds the array; the text is kept so the refusal is thrown in V2's words.
    let refusal: String?

    var success: Bool {
        status == "1" || message == "OK"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decode(String.self, forKey: .status)
        self.message = try container.decode(String.self, forKey: .message)
        if let refusal = try? container.decode(String.self, forKey: .result) {
            self.result = []
            self.refusal = refusal
        } else {
            self.result = try container.decode([EthereumTokenInfo].self, forKey: .result)
            self.refusal = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case message
        case result
    }

    func cryptoInfo<C: CryptoContract>(on mainContract: C) throws -> SimpleTokenInfo<C> {
        guard success, let tokenInfo = result.first else {
            throw EthereumScannerResponseError.requestFailed(refusal ?? "<< Unknown Error >>")
        }

        return tokenInfo.cryptoInfo(on: mainContract)
    }

    // https://docs.etherscan.io/api-endpoints/tokens#get-token-info-by-contractaddress
    static func httpQuery(forToken contract: any CryptoContract) -> [URLQueryItem] { [
        .init(name: "module", value: "token"),
        .init(name: "action", value: "tokeninfo"),
        .init(name: "contractaddress", value: contract.address)
    ] }
}

struct EthereumTokenInfo: Decodable {
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
    let aggregatorId: String?

    // V2's answer writes `github`, where the 2023 decode read `gitHub`.
    private enum CodingKeys: String, CodingKey {
        case contractAddress, tokenName, symbol, divisor, tokenType, totalSupply, blueCheckmark, description, website
        case email, blog, reddit, slack, facebook, twitter, bitcointalk
        case gitHub = "github"
        case telegram, wechat, linkedin, discord, whitepaper, tokenPriceUSD, aggregatorId
    }

    func cryptoInfo<C: CryptoContract>(on mainContract: C) -> SimpleTokenInfo<C> {
        SimpleTokenInfo(tokenInfo: self, mainContract: mainContract)
    }
}

private extension SimpleTokenInfo {
    init(tokenInfo: EthereumTokenInfo, mainContract: Contract) {
        self.contractAddress = Contract(address: tokenInfo.contractAddress)
        self.equivalentContracts = .init()
        self.tokenName = tokenInfo.tokenName
        self.symbol = tokenInfo.symbol
        self.imageURL = nil
        self.tokenType = tokenInfo.tokenType

        let totalSupply = Int128(tokenInfo.totalSupply)
        self.totalSupply = totalSupply == nil
            ? nil
            : .init(
                quantity: totalSupply!,
                currency: mainContract
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
        self.aggregatorId = tokenInfo.aggregatorId
        self.decimals = Int(tokenInfo.divisor)
    }
}
