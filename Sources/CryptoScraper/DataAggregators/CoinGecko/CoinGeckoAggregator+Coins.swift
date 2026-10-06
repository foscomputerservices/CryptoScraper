// CoinGeckoAggregator+Coins.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
import Synchronization

public extension CoinGeckoAggregator {
    /// Returns the known tokens for a given ``CryptoContract`` type
    func tokens<Contract: CryptoContract & Sendable>(for contract: Contract.Type) async throws -> Set<SimpleTokenInfo<Contract>> {
        let response: [CoinGeckoTokenResponse]
        if let cachedTokensResponse {
            response = cachedTokensResponse
        } else {
            response = try await Self.endPoint
                .appending(path: "coins/list")
                .appending(
                    queryItems: TokensResponse.httpQuery()
                ).fetch(errorType: CoinGeckoError.self)
            cachedTokensResponse = response
        }

        return try response.tokens(for: contract)
    }
}

private struct TokensResponse: Decodable {
    // https://www.coingecko.com/en/api/documentation
    static func httpQuery() -> [URLQueryItem] { [
        .init(name: "include_platform", value: "true")
    ] }
}

protocol CoinGeckoTokenInfo: TokenInfo {
    var coinGeckoId: String { get }
    var coinGeckoSymbol: String { get }
    var coinGeckoName: String { get }
    var coinGeckoPlatforms: [String: String?] { get }
}

extension SimpleTokenInfo<BitcoinContract>: CoinGeckoTokenInfo {
    var coinGeckoId: String {
        "bitcoin"
    }
    
    var coinGeckoSymbol: String {
        "btc"
    }
    
    var coinGeckoName: String {
        "btc"
    }
    
    var coinGeckoPlatforms: [String : String?] {
        [:]
    }
}

struct CoinGeckoTokenResponse: Decodable {
    let id: String
    let symbol: String
    let name: String
    let platforms: [String: String?]

    fileprivate func tokens<Contract: CryptoContract>(for contract: Contract.Type) throws -> [Token<Contract>] {
        let contracts = try equivalentContracts()

        return try contracts.reduce(into: [Token<Contract>]()) { result, next in
            let chain = next.chain as (any CryptoChain)
            let mainContract = chain.mainContract as (any CryptoContract)

            guard type(of: mainContract) == Contract.self else {
                return
            }

            try result.append(Token(
                contractAddress: chain.contract(for: next.address) as! Contract,
                tokenResponse: self,
                equivalentContracts: contracts
                    .filter { $0.isSame(as: next) }
                    .map { $0 as! Contract }
            ))
        }
    }

    fileprivate struct Token<Contract: CryptoContract>: CoinGeckoTokenInfo {
        // MARK: TokenInfo

        let contractAddress: Contract
        let equivalentContracts: [Contract]
        let tokenName: String
        let symbol: String
        var aggregatorId: String? { coinGeckoId }

        // MARK: CoinGeckoTokenInfo
        let coinGeckoId: String
        var coinGeckoName: String { tokenName }
        var coinGeckoSymbol: String { symbol }
        let coinGeckoPlatforms: [String : String?]

        init(contractAddress: Contract, tokenResponse: CoinGeckoTokenResponse, equivalentContracts: [Contract]) {
            self.contractAddress = contractAddress
            self.tokenName = tokenResponse.name
            self.symbol = tokenResponse.symbol
            self.equivalentContracts = equivalentContracts
            self.coinGeckoId = tokenResponse.id
            self.coinGeckoPlatforms = tokenResponse.platforms
        }
    }

    private func equivalentContracts() throws -> [any CryptoContract] {
        try platforms.compactMap { platform, contractId in
            guard
                let chain = platform.chain,
                let contractId,
                !contractId.isEmpty
            else {
                return nil
            }

            return try chain.contract(for: contractId) as (any CryptoContract)
        }
    }
}

private extension Collection<CoinGeckoTokenResponse> {
    func tokens<Contract: CryptoContract>(for contract: Contract.Type) throws -> Set<SimpleTokenInfo<Contract>> {
        try reduce(into: Set<SimpleTokenInfo<Contract>>()) { result, next in
            for token in try next.tokens(for: contract) {
                result.insert(.init(tokenInfo: token))
            }
        }
    }
}

// Debug bookkeeping written from whichever domain decodes a response, so it is held behind a `Mutex`.
private let unknownChain = Mutex<Set<String>>([])

private extension String {
    var chain: (any CryptoChain)? {
        switch self {
        case "ethereum": return .ethereum
        case "fantom": return .fantom
        case "binance-smart-chain": return .binance
        case "polygon-pos": return .polygon
        case "optimistic-ethereum": return .optimism
        case "tron": return .tron

        // TODO: Unsupported chains
        case "arbitrum-one", "iotex", "wanchain", "avalanche", "algorand",
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
             "polkadot", "wemix-network", "oasys", "celer-network", "vite", "stacks", "tombchain", "super-zero", "hoo", "komodo", "ardor", "kusama", "polygon-zkevm", "acala", "core", "terra-2", "zksync", "empire", "stratis", "metaverse-etp", "enq-enecuum", "omni", "bitshares", "thorchain", "pulsechain", "sui", "base", "ordinals", "linea", "the-open-network", "kujira", "trustless-computer", "mantle", "eos-evm", "rollux", "callisto", "tenet", "neon-evm", "alephium", "archway", "orenium", "x-layer", "oraichain", "blast", "starknet", "akash", "sei-network", "degen", "lightlink", "mode", "opbnb", "bitrock", "shimmer_evm", "neutron", "migaloo", "manta-pacific", "radix", "injective", "fraxtal", "bsquared-network", "internet-computer", "juno", "beam", "bevm", "bitcanna", "bifrost-network", "scroll", "merlin-chain", "humanode", "immutable", "map-protocol", "shibarium", "lukso", "comdex", "ergo", "drc-20", "zora-network", "flow", "gravity-bridge", "crescent", "hypra-network", "xpla", "oasis-sapphire", "defichain", "kadena", "ki-chain", "astar-zkevm", "massa", "aura-network", "dymension", "zklink-nova", "omniflix", "octaspace", "clover", "quicksilver", "saga", "casper-network", "sge", "rails-network", "omax", "valobit", "filecoin", "zetachain", "zkfair", "wax":
            return nil

        default:
            #if DEBUG
            if !isEmpty, unknownChain.withLock({ $0.insert(self).inserted }) {
//                print("CoinGeckoAggregator: Unknown chain \(self)")
            }
            #endif
            return nil
        }
    }
}
