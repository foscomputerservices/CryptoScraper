// ScannerNoNetworkTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import Foundation
import FOSTesting
import Testing

/// Design § 1.3 "Never nil" and § 6 "The exchange scanners": every chain specifies a scanner, even one that does
/// nothing. No network: nothing here calls a scanner that reaches one.
@Suite struct ScannerNoNetworkTests {
    @Test func theScannerIsReadWithNoUnwrap() {
        #expect(EthereumChain.default.scanner.userReadableName == "Etherscan")
    }

    @Test func eachChainSpecifiesAScanner() {
        let names = [
            BitcoinChain.default.scanner.userReadableName, EthereumChain.default.scanner.userReadableName,
            BinanceSmartChain.default.scanner.userReadableName, PolygonChain.default.scanner.userReadableName,
            OptimismChain.default.scanner.userReadableName, FantomChain.default.scanner.userReadableName,
            TronChain.default.scanner.userReadableName, ZeroAmountChain.default.scanner.userReadableName
        ]
        #expect(names.allSatisfy { !$0.isEmpty })
    }

    // MARK: NilScanner, as ZeroAmountScanner answers

    @Test func theNilScannerIsNamedNoScanner() {
        #expect(NilScanner<EthereumContract>().userReadableName == "No scanner")
    }

    @Test func theNilScannerAnswersZeroForAnAccount() async throws {
        let balance = try await NilScanner<EthereumContract>().getBalance(forAccount: .stub())
        #expect(balance == Amount(quantity: 0, currency: EthereumChain.default.mainContract))
    }

    @Test func theNilScannerAnswersZeroForAToken() async throws {
        let balance = try await NilScanner<TronContract>().getBalance(forToken: .stub(), forAccount: .stub())
        #expect(balance == Amount(quantity: 0, currency: TronChain.default.mainContract))
    }

    @Test func theNilScannerHasNoTransactions() async throws {
        #expect(try await NilScanner<BitcoinContract>().getTransactions(forAccount: .stub()).isEmpty)
        #expect(try NilScanner<BitcoinContract>().loadTransactions(from: Data("[]".utf8)).isEmpty)
    }

    @Test func theNilScannerAnswersAsTheZeroAmountScannerDoes() async throws {
        let zero = try await ZeroAmountChain.default.scanner.getBalance(forAccount: .zero)
        let nilScanner = try await NilScanner<ZeroAmountContract>().getBalance(forAccount: .zero)
        #expect(zero == nilScanner)
    }
}
