// EtherScanTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSFoundation
import XCTest

final class EtherScanTests: XCTestCase {
    private static let ethContractAddress: String = {
        guard let address = ProcessInfo.processInfo.environment["ETH_TEST_CONTRACT_ADDRESS"] else {
            fatalError("Environment ETH_TEST_CONTRACT_ADDRESS is not set")
        }

        return address
    }()

    // User account contract
    let accountContract = EthereumContract(address: EtherScanTests.ethContractAddress)

    private static let etherScan = Etherscan()!
    private var etherScan: Etherscan { EtherScanTests.etherScan }

    func testGetAccountBalance() async throws {
        let balance = try await etherScan.getBalance(forAccount: accountContract)
        XCTAssertGreaterThan(balance.quantity, 0)

        let ethBalance = balance.value(units: .ether)
        XCTAssertGreaterThan(ethBalance, 0)
    }

    func testGetTransactions() async throws {
        sleep(2) // Overcomes rate limiting

        do {
            let transactions = try await etherScan.getTransactions(
                forAccount: accountContract
            )
            XCTAssertGreaterThan(transactions.count, 0)
        } catch let e as EthereumScannerResponseError {
            if !e.rateLimitReached {
                XCTFail(e.localizedDescription)
            } else {
                print("*************************************************")
                print("*** Error: Unable to test, rate-limit reached ***")
                print("*************************************************")
            }
        } catch let e as DataFetchError {
            XCTFail(e.localizedDescription)
        } catch let e {
            XCTFail(e.localizedDescription)
        }
    }

    func testGetTokenBalance_ETH() async throws {
        let ethToken = accountContract.chain.mainContract!

        do {
            let ethBalance = try await etherScan.getBalance(forToken: ethToken, forAccount: accountContract)
            XCTAssertGreaterThan(ethBalance.quantity, 0)
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }

    func testGetERC20TokenTransactions_ETH() async throws {
        let ethToken = accountContract.chain.mainContract!

        let transactions = try await etherScan.getERC20Transactions(forToken: ethToken, forAccount: accountContract)

        // All ETH transactions are from getTransactions()
        XCTAssertEqual(transactions.count, 0)
    }

//    func testGetTokenBalance_RLC() async throws {
//        let rlcToken = EthereumContract(address: "0x607F4C5BB672230e8672085532f7e901544a7375")
//
//        do {
//            let ethBalance = try await etherScan.getBalance(forToken: rlcToken, forAccount: accountContract)
//            XCTAssertGreaterThan(ethBalance.quantity, 0)
//            XCTAssertEqual(ethBalance.contract.address, rlcToken.address)
//        } catch let e as EthereumScannerResponseError {
//            print("*** Error: \(e.localizedDescription)")
//            throw e
//        }
//    }

    func testGetERC20TokenTransactions_RLC() async throws {
        let rlcToken = EthereumContract(address: "0x607F4C5BB672230e8672085532f7e901544a7375")

        do {
            let rlcTxns = try await etherScan.getERC20Transactions(forToken: rlcToken, forAccount: accountContract)
            XCTAssertGreaterThan(rlcTxns.count, 0)
        } catch let e as EthereumScannerResponseError {
            print("*** Error: \(e.localizedDescription)")
            throw e
        }
    }
}
