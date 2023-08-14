// CoinMarketCapAggregator+Coins.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public extension CoinMarketCapAggregator {
    /// Returns the coins known to the aggregator
    ///
    /// - See also: https://coinmarketcap.com/api/documentation/v1/#operation/getV1CryptocurrencyMap
    func tokens<Contract: CryptoContract>(for contract: Contract.Type) async throws -> Set<SimpleTokenInfo<Contract>> {
        let response: CurrencyMapResponse

        if let cachedResponse = cachedMapResponse {
            response = cachedResponse
        } else {
            response = try await Self.endPoint
                .appending(path: "v1/cryptocurrency/map")
                .fetch(
                    headers: headers(),
                    errorType: CoinMarketCapResponseError.self
                )

            // Cache the response for later use
            cachedMapResponse = response
        }

        return try response.tokens(for: contract)
    }

    private func headers() throws -> [(field: String, value: String)] {
        guard let apiKey = Self.apiKey else {
            throw CoinMarketCapError(message: "CryptoMarketCapApiKey is not specified")
        }

        return [(field: "X-CMC_PRO_API_KEY", value: apiKey)]
    }
}

struct CurrencyMapResponse: Decodable {
    fileprivate let data: [CurrencyMapItem]
    let status: CoinMarketCapError.ErrorStatus

    func tokens<Contract: CryptoContract>(for contract: Contract.Type) throws -> Set<SimpleTokenInfo<Contract>> {
        try data.tokens(for: contract)
    }
}

private struct CurrencyMapItem: Decodable {
    let id: Int
    let name: String
    let symbol: String
    let slug: String
    let isActive: Int
    let status: String?
    let firstHistoricalData: String
    let lastHistoricalData: String?
    let platform: Platform?

    func token<Contract: CryptoContract>(for contract: Contract.Type) throws -> CoinMarketCapTokenInfo<Contract>? {
        guard let platform, let chain = platform.chain else {
            return nil
        }
        guard (chain.mainContract as (any CryptoContract)) is Contract else {
            return nil
        }

        return try CoinMarketCapTokenInfo(
            response: self,
            contract: chain.contract(for: platform.tokenAddress) as! Contract
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbol
        case slug
        case isActive = "is_active"
        case status
        case firstHistoricalData = "first_historical_data"
        case lastHistoricalData = "last_historical_data"
        case platform
    }
}

private struct CoinMarketCapTokenInfo<Contract: CryptoContract>: TokenInfo {
    let contractAddress: Contract
    let tokenName: String
    let symbol: String

    init(response: CurrencyMapItem, contract: Contract) {
        self.contractAddress = contract
        self.tokenName = response.name
        self.symbol = response.symbol
    }
}

/// Metadata about the parent cryptocurrency platform this cryptocurrency belongs to
private struct Platform: Decodable {
    let id: Int
    let name: String
    let symbol: String
    let slug: String
    let tokenAddress: String

    var chain: (any CryptoChain)? {
        name.chain
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbol
        case slug
        case tokenAddress = "token_address"
    }
}

private extension Collection<CurrencyMapItem> {
    func tokens<Contract: CryptoContract>(for contract: Contract.Type) throws -> Set<SimpleTokenInfo<Contract>> {
        try compactMap { try $0.token(for: contract) }
            .reduce(into: Set<SimpleTokenInfo<Contract>>()) { result, next in
                result.insert(.init(tokenInfo: next))
            }
    }
}

private var unknownChain = Set<String>()

private extension String {
    var chain: (any CryptoChain)? {
        switch self {
        case "Ethereum": return .ethereum
        case "Fantom": return .fantom
        case "BNB", "BNB Smart Chain (BEP20)": return .binance
        case "Polygon": return .polygon
        case "Optimism": return .optimism
        case "TRON", "Tron20": return .tron

        // TODO: Unsupported chains
        case "Bitcicoin", "Chiliz", "Telos", "Super Zero Protocol", "KardiaChain", "Waves", "Velas", "Cardano", "EthereumPoW", "EOS", "XRP", "Energi", "RSK Smart Bitcoin", "IoTeX", "Fuse Network", "Conflux", "SX Network", "Algorand", "Moonriver", "HTMLCOIN", "CANTO", "Ethereum Classic", "Step App", "Terra Classic", "Secret", "DeFi Kingdoms", "Astar", "Oasis Network", "Boba Network", "Celo", "Cosmos", "OKC Token", "SORA", "XDC Network", "Songbird", "Osmosis", "MultiversX", "Karura", "Ontology", "Tezos", "Klaytn", "Wanchain", "VeChain", "Polkadot", "Cronos", "TomoChain", "KuCoin Token", "Avalanche", "Aurora", "MetisDAO", "Aptos", "Solana", "Harmony", "Meter Governance", "Toncoin", "Hedera", "Huobi Token", "NEAR Protocol", "NEM", "Bitcoin Cash", "Zilliqa", "Evmos", "Stellar", "Stacks", "Elastos", "Everscale", "Bitgert", "Dogecoin", "Gnosis", "Fusion", "Neo", "Moonbeam", "Terra", "Rootstock Smart Bitcoin", "Core", "OKT Chain", "Arbitrum", "Kava", "Radix", "zkSync", "Fuse", "Sui", "WEMIX", "Klever", "NULS", "BNB Beacon Chain (BEP2)", "Avalanche C-Chain", "RSK RBTC", "Tron10", "ONT", "Xinfin Network", "Arbitrum Nova", "Gnosis Chain", "HECO", "Fusion Network", "zkSync Era", "OKExChain", "KCC", "Elrond", "Sora", "Hedera Hashgraph", "Bitcichain", "XRP Ledger", "IoTex", "Near", "Metis Andromeda", "Songbird Network", "Theta Network", "Avalanche DFK", "Flow", "SUI", "Dogechain", "Canto", "Step", "Wemix", "TON", "PulseChain", "EOS EVM", "Ordinals-BRC20", "Polygon zkEVM", "Mantle", "NEON EVM", "Linea", "Base":
            return nil

        default:
            #if DEBUG
            if !isEmpty, !unknownChain.contains(self) {
                unknownChain.insert(self)
                print("CoinMarketCapAggregator: Unknown chain \(self)")
            }
            #endif
            return nil
        }
    }
}
