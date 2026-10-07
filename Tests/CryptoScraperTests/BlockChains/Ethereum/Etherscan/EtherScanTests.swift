// EtherScanTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoAsset
import CryptoScraper
import FOSFoundation
import XCTest

/// Skips the test when Etherscan's API V2 refuses `read` for the key's plan ("Free API access is not supported for
/// this chain", "API Pro endpoint") or does not serve the chain ("Missing or unsupported chainid"): V2's answer, not
/// this library's failure. Any other answer, and any other error, lets the test run.
func skipWhereEtherscanV2Refuses(_ read: () async throws -> Void) async throws {
    do {
        try await read()
    } catch let EthereumScannerResponseError.requestFailed(text) {
        for refusal in ["Free API access is not supported", "API Pro endpoint", "Missing or unsupported chainid"]
            where text.contains(refusal) {
            throw XCTSkip("Etherscan V2 refuses this key or chain: \(text)")
        }
    }
}

final class EtherScanTests: XCTestCase {
    private static let ethContractAddress: String = {
        guard let address = ProcessInfo.processInfo.environment["ETH_TEST_CONTRACT_ADDRESS"] else {
            fatalError("Environment ETH_TEST_CONTRACT_ADDRESS is not set")
        }

        return address
    }()

    // User account contract
    let accountContract = EthereumContract(address: EtherScanTests.ethContractAddress)

    private static let etherScan = Etherscan()
    private var etherScan: Etherscan { EtherScanTests.etherScan }

    override func setUp() async throws {
        sleep(1) // One key, one rate: V2 answers a free key 3 calls a second across every chain
    }

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

    /// The oracle (design § 2.5, § 6): Etherscan's divisor for USDC is 6, the statement's decimals. Token info is an API
    /// Pro endpoint, so with a free key the test is skipped in V2's words; it needs a Standard key.
    func testGetInfo_USDCsDivisorIsTheDeclaredDecimals() async throws {
        let usdc = try EthereumChain.default.contract(for: XCTUnwrap(EIP155.Ethereum.usdc.instance.address))

        try await skipWhereEtherscanV2Refuses { _ = try await etherScan.getInfo(forToken: usdc) }
        let info = try await etherScan.getInfo(forToken: usdc)
        XCTAssertEqual(info.decimals, 6)
        XCTAssertEqual(info.decimals, EIP155.Ethereum.usdc.decimals)
    }

    /// V2 serves no Fantom: FTMScan's read is refused as an unsupported chain, never answered with a zero. When this
    /// fails, V2 serves Fantom again and FTMScanTests run.
    func testV2DoesNotServeFantomsChain() async throws {
        do {
            _ = try await FTMScan().getBalance(forAccount: FantomChain.default.mainContract)
            XCTFail("V2 answered Fantom's chain")
        } catch let EthereumScannerResponseError.requestFailed(text) {
            XCTAssertTrue(text.contains("Missing or unsupported chainid"))
        }
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
