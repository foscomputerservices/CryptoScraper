// EtherScanTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import XCTest

final class EtherScanTests: XCTestCase {
    static let ethContractAddress: String = {
        guard let address = ProcessInfo.processInfo.environment["ETH_TEST_CONTRACT_ADDRESS"] else {
            fatalError("Environment ETH_TEST_CONTRACT_ADDRESS is not set")
        }

        return address
    }()

    // User account contract
    let accountContract = EthereumContract(address: EtherScanTests.ethContractAddress)

    private static let etherScan = Etherscan()
    private var etherScan: Etherscan { EtherScanTests.etherScan }

    func testGetAccountBalance() async throws {
        let balance = try await etherScan.getBalance(forAccount: accountContract)
        XCTAssertGreaterThan(balance.quantity, 0)

        let ethBalance = accountContract.displayAmount(amount: balance.quantity, inUnits: .ether)
        XCTAssertGreaterThan(ethBalance, 0)
    }

    func testGetTransactions() async throws {
        let transactions = try await etherScan.getTransactions(forAccount: accountContract)
        XCTAssertGreaterThan(transactions.count, 0)
    }

    func testGetTokenBalance_ETH() async throws {
        let ethToken = accountContract.chain.mainContract!

        do {
            let ethBalance = try await etherScan.getBalance(forToken: ethToken, forAccount: accountContract)
            XCTAssertGreaterThan(ethBalance.quantity, 0)
            print("*** Ethereum balance \(ethBalance.quantity)")
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }

    func testGetTokenBalance_RLC() async throws {
        let rlcToken = EthereumContract(address: "0x607F4C5BB672230e8672085532f7e901544a7375")

        do {
            let ethBalance = try await etherScan.getBalance(forToken: rlcToken, forAccount: accountContract)
            XCTAssertGreaterThan(ethBalance.quantity, 0)
            XCTAssertEqual(ethBalance.contract.address, rlcToken.address)
            print("*** Ethereum balance \(ethBalance.quantity)")
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }
}
