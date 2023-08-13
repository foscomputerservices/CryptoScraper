// ZeroAmountChain.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation

public final class ZeroAmountChain: CryptoChain {
    public let userReadableName: String = "Zero Amount Chain"
    public let scanner: ZeroAmountScanner?
    public var mainContract: ZeroAmountContract! { ZeroAmountContract(address: "") }
    public func contract(for address: String) throws -> ZeroAmountContract { .zero }

    public func loadChainTokens(from dataAggregator: CryptoDataAggregator) async throws {
        // N/A
    }

    public func tokenInfo(for address: String) -> SimpleTokenInfo<ZeroAmountContract>? { nil }

    public var chainTokenInfos: Set<SimpleTokenInfo<ZeroAmountContract>> { .init() }

    public static var `default`: ZeroAmountChain { .init() }

    public init() {
        self.scanner = ZeroAmountScanner()
    }
}
