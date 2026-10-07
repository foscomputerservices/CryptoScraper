// XRPLedgerChain.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import Foundation
import Synchronization

/// XRP Ledger, `XRPL.XRPLedger.chainId`: its contracts ``XRPLedgerContract``, its scanner ``Rippled``
public final class XRPLedgerChain: CryptoChain, Sendable {
    // MARK: CryptoChain

    /// The chain's CAIP-2 identifier, the first part of every identity on it
    public let id: String = XRPL.XRPLedger.chainId

    /// "XRP Ledger"
    public let userReadableName: String = "XRP Ledger"

    /// The tokens a data aggregator listed on the chain, once loaded (``loadChainTokens(from:)``)
    public var chainTokenInfos: Set<SimpleTokenInfo<XRPLedgerContract>> {
        tokens.withLock { tokens in
            guard let result = tokens?.values else { return [] }

            return .init(result)
        }
    }

    /// XRP, the chain's coin, under the placeholder address `xrp`
    public let mainContract: XRPLedgerContract!

    /// The contract at `address`, validated as a classic address (`r…`, 25 to 35 characters of the ledger's base58
    /// alphabet) or a token as `<currency>.<issuer>` (a 3-character or 40-hex-digit currency code), or the coin's
    /// placeholder; kept as given
    ///
    /// - Throws: ``BlockChainError/malformedAddress(_:)`` for any other address
    public func contract(for address: String) throws -> XRPLedgerContract {
        let contract = XRPLedgerContract(address: address)
        guard contract == mainContract || XRPLedgerContract.isWellFormed(contract.address) else {
            throw BlockChainError.malformedAddress(address)
        }
        return contract
    }

    /// Loads the tokens `dataAggregator` lists on the chain
    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        try await loadChainTokens(
            from: dataAggregator.tokens(
                for: XRPLedgerContract.self
            )
        )
    }

    // The table is loaded after the singleton exists (``loadChainTokens(from:)``) and read from any
    // concurrency domain, so it lives behind a `Mutex`; every other stored property is a `let`.
    private let tokens = Mutex<[String: SimpleTokenInfo<XRPLedgerContract>]?>(nil)
    private func loadChainTokens(from newTokens: some Collection<SimpleTokenInfo<XRPLedgerContract>>) {
        tokens.withLock { tokens in
            tokens = tokens ?? [:]

            for token in newTokens {
                tokens![token.contractAddress.address] = token
            }
        }
    }

    /// The chain's scanner: a public rippled server's JSON-RPC, `s1.ripple.com:51234`
    public let scanner: Rippled = .init()

    /// The token at `address` a data aggregator listed, once loaded; `nil` before or for any other
    public func tokenInfo(for address: String) -> SimpleTokenInfo<XRPLedgerContract>? {
        tokens.withLock { $0?[address] }
    }

    static let xrpContractAddress = "xrp"

    /// The one XRP Ledger chain
    public static let `default`: XRPLedgerChain = .init()

    private init() {
        self.mainContract = .init(address: Self.xrpContractAddress)
    }
}

public extension CryptoChain where Self == XRPLedgerChain {
    /// The one XRP Ledger chain
    static var xrpLedger: XRPLedgerChain { .default }
}
