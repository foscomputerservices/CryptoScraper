// TronScan+Accounts.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension TronScan {
    /// Returns the balance (in TRX) of the given account
    ///
    /// - Parameter account: The Tron account to query the balance for
    func getBalance(forAccount account: Contract) async throws -> Amount<Contract> {
        let response: BalanceResponse = try await Self.endPoint.appending(path: "account").appending(
            queryItems: BalanceResponse.httpQuery(account: account)
        ).fetch()

        return try response.amount(forAccount: account.chain.mainContract)
    }

    /// Returns the balance (in TRX) for a given token in the given account
    ///
    /// - Parameters:
    ///   - contract: The ``CryptoContract`` of the token to query
    ///   - address: The ``CryptoContract`` address that holds the token
    func getBalance(forToken contract: Contract, forAccount account: Contract) async throws -> Amount<Contract> {
        let response: BalanceResponse = try await Self.endPoint.appending(path: "account").appending(
            queryItems: BalanceResponse.httpQuery(account: account)
        ).fetch()

        return try response.amount(forToken: contract, forAccount: account.chain.mainContract)
    }
}

private struct BalanceResponse: Decodable {
    private let trc721token_balances: [TRC721tokenBalance]
    private let trc20token_balances: [TRC20TokenBalance]
    private let tokenBalances: [TokenBalance]
    private let balances: [Balance]
    private let tokens: [Token]

    private var responses: [TRBalance] { trc721token_balances + trc20token_balances + tokenBalances }

    var success: Bool {
        !responses.isEmpty
    }

    func amount(forAccount trxContract: TronContract) throws -> Amount<TronContract> {
        guard success else {
            throw TronScanResponseError.unknownContract(trxContract.address)
        }

        return .init(quantity: responses.trxBalance, currency: TronChain.default.mainContract)
    }

    func amount(forToken contract: TronContract, forAccount trxContract: TronContract) throws -> Amount<TronContract> {
        guard success else {
            throw TronScanResponseError.unknownContract(trxContract.address)
        }

        return .init(quantity: responses.trxBalance(forToken: contract), currency: contract)
    }

    // https://github.com/tronscan/tronscan-frontend/blob/dev2019/document/api.md#4
    static func httpQuery(account: TronContract) -> [URLQueryItem] { [
        .init(name: "address", value: account.address)
    ] }

    private struct Response: Decodable {
        let finalBalance: UInt64
        let numberOfTransactions: Int
        let totalReceived: UInt64

        private enum CodingKeys: String, CodingKey {
            case finalBalance = "final_balance"
            case numberOfTransactions = "n_tx"
            case totalReceived = "total_received"
        }
    }
}

private protocol TRBalance {
    var tokenId: String { get }
    var balance: String { get }
    var tokenName: String { get }
    var tokenAbbr: String { get }
}

private extension TRBalance {
    var trxBalance: UInt128? {
        UInt128(balance)
    }
}

private extension Collection<TRBalance> {
    var trxBalance: UInt128 {
        compactMap(\.trxBalance)
            .reduce(UInt128(0), +)
    }

    func trxBalance(forToken contract: TronContract) -> UInt128 {
        filter { contract.isChainToken ? $0.tokenAbbr == "trx" : $0.tokenId == contract.address }
            .compactMap(\.trxBalance)
            .reduce(UInt128(0), +)
    }
}

private struct TRC721tokenBalance: TRBalance, Decodable {
    let tokenId: String
    let balance: String
    let tokenName: String
    let tokenAbbr: String
}

private struct TRC20TokenBalance: TRBalance, Decodable {
    let tokenId: String
    let balance: String
    let tokenName: String
    let tokenAbbr: String
    let tokenDecimal: UInt
    let tokenCanShow: UInt
    let tokenType: String
    let tokenLogo: String
    let vip: Bool
//    let tokenPriceInTrx: Double
//    let amount: Double
    let nrOfTokenHolders: UInt64
    let transferCount: UInt64
}

private struct TokenBalance: TRBalance, Decodable {
//    let amount: String
//    let tokenPriceInTrx: Double
    let tokenId: String
    let balance: String
    let tokenName: String
    let tokenDecimal: UInt
    let tokenAbbr: String
    let tokenCanShow: UInt
    let tokenType: String
    let vip: Bool
    let tokenLogo: String
}

private struct Balance: TRBalance, Decodable {
//    let amount: Double
//    let tokenPriceInTrx: Double
    let tokenId: String
    let balance: String
    let tokenName: String
    let tokenDecimal: UInt
    let tokenAbbr: String
    let tokenCanShow: UInt
    let tokenType: String
    let vip: Bool
    let tokenLogo: String
}

private struct Token: TRBalance, Decodable {
//    let amount: Double
//    let tokenPriceInTrx: Double
    let tokenId: String
    let balance: String
    let tokenName: String
    let tokenDecimal: UInt
    let tokenAbbr: String
    let tokenCanShow: UInt
    let tokenType: String
    let vip: Bool
    let tokenLogo: String
}
