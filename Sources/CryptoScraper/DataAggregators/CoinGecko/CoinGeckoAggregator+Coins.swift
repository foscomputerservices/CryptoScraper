// CoinGeckoAggregator+Coins.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension CoinGeckoAggregator {
    /// Returns the coins known to the aggregator
    func listCoins() async throws -> [CryptoInfo] {
        let response: [CoinResponse] = try await Self.endPoint
            .appending(path: "coins/list")
            .appending(
                queryItems: CoinsResponse.httpQuery()
            ).fetch(errorType: CoinGeckoError.self)

        return try response.coins()
    }
}

private struct CoinsResponse: Decodable {
    // https://www.coingecko.com/en/api/documentation
    static func httpQuery() -> [URLQueryItem] { [
        .init(name: "include_platform", value: "true")
    ] }
}

private struct CoinResponse: Decodable {
    let id: String
    let symbol: String
    let name: String
    let platforms: [String: String?]

    func coins() throws -> [CryptoInfo] {
        try Coin.coins(from: self)
    }

    private struct Coin: CryptoInfo {
        let contractAddress: CryptoContract
        let tokenName: String
        let symbol: String
        let tokenType: String? = nil
        let totalSupply: CryptoAmount? = nil
        let blueCheckmark: Bool? = nil
        let description: String? = nil
        let website: URL? = nil
        let email: String? = nil
        let blog: URL? = nil
        let reddit: URL? = nil
        let slack: String? = nil
        let facebook: URL? = nil
        let twitter: URL? = nil
        let gitHub: URL? = nil
        let telegram: URL? = nil
        let wechat: URL? = nil
        let linkedin: URL? = nil
        let discord: URL? = nil
        let whitepaper: URL? = nil

        static func coins(from coinResponse: CoinResponse) throws -> [CryptoInfo] {
            var result = [Coin]()

            for platform in coinResponse.platforms where platform.value != nil && (!platform.key.isEmpty && !platform.value!.isEmpty) {
                guard let chain = platform.key.chain else {
                    continue
                }
                let contractAddress = try chain.contract(for: platform.value!)

                result.append(.init(contractAddress: contractAddress, coinResponse: coinResponse))
            }

            return result
        }

        private init(contractAddress: CryptoContract, coinResponse: CoinResponse) {
            self.contractAddress = contractAddress
            self.tokenName = coinResponse.name
            self.symbol = coinResponse.symbol
        }
    }
}

private extension Collection<CoinResponse> {
    func coins() throws -> [CryptoInfo] {
        try reduce(into: [CryptoInfo]()) { result, next in
            for coin in try next.coins() {
                result.append(coin)
            }
        }
    }
}

private var unknownChain = Set<String>()

private extension String {
    var chain: CryptoChain? {
        switch self {
        case "ethereum": return .ethereum
        case "fantom": return .fantom
        case "binance-smart-chain": return .binance
        case "polygon-pos": return .polygon
        case "optimistic-ethereum": return .optimism

        // TODO: Unsupported chains
        case "tron", "arbitrum-one", "iotex", "wanchain", "avalanche", "algorand",
             "tomochain", "cronos", "energi", "moonriver", "solana", "zilliqa", "icon",
             "astar", "cube", "neo", "telos", "oasis", "tezos", "aurora", "yocoin", "bitgert", "dogechain",
             "harmony-shard-0", "stellar", "huobi-token", "bitkub-chain", "sora", "xdai",
             "smartbch", "near-protocol", "cardano", "kardiachain", "karura", "chiliz",
             "boba", "Bitcichain", "metis-andromeda", "elrond", "osmosis", "syscoin", "klay-token",
             "moonbeam", "celo", "secret", "terra", "evmos", "cosmos", "okex-chain", "proof-of-memes",
             "velas", "ronin", "ethereumpow", "fuse", "elastos", "theta", "milkomeda-cardano",
             "meter", "hedera-hashgraph", "binancecoin", "xdc-network", "aptos", "xrp",
             "arbitrum-nova", "nuls", "rootstock", "mixin-network", "songbird", "canto",
             "fusion-network", "hydra", "kucoin-community-chain", "kava", "step-network",
             "defi-kingdoms-blockchain", "echelon", "ethereum-classic", "vechain", "bitcoin-cash",
             "waves", "nem", "everscale", "exosama", "findora", "gochain", "godwoken", "coinex-smart-chain",
             "conflux", "bittorrent", "shiden network", "sx-network", "ontology", "thundercore", "flare-network",
             "hoo-smart-chain", "function-x", "qtum", "onus", "skale", "eos", "ShibChain", "factom",
             "polkadot", "wemix-network", "oasys", "celer-network", "vite", "stacks", "tombchain", "super-zero", "hoo":
            return nil

        default:
            #if DEBUG
            if !unknownChain.contains(self) {
                unknownChain.insert(self)
                print("\(self)")
            }
            #endif
            return nil
        }
    }
}
