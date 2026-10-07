// IotaChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// IOTA, `IOTA.Iota.chainId`: its contracts ``IotaContract``, its scanner ``IotaRPC``
public final class IotaChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = IOTA.Iota.chainId

    /// "IOTA"
    public let userReadableName: String = "IOTA"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<IotaContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// IOTA, the chain's coin, under the placeholder address `iota`
    public let mainContract: IotaContract!

    /// The contract at `address`, validated as an address or an object, `0x` and 64 hex digits, or the coin's
    /// placeholder; lower-cased, since the address is a number
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> IotaContract {
        let contract = IotaContract(address: address)
        guard contract == mainContract || IotaContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: IotaContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<IotaContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<IotaContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: IOTA's public JSON-RPC, `api.mainnet.iota.cafe`
    public let scanner: IotaRPC = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<IotaContract>? {
        tokens.withLock { $0?[address] }
    }

    static let iotaContractAddress = "iota"

    /// The one IOTA chain
    public static let `default`: IotaChain = .init()

    private init() {
        self.mainContract = .init(address: Self.iotaContractAddress)
    }
}

public extension CryptoChain where Self == IotaChain {
    /// The one IOTA chain
    static var iota: IotaChain { .default }
}
