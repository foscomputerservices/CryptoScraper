// EVMNormalTransactionTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import XCTest

final class EVMNormalTransactionTests: XCTestCase {
    func testEVMFunctionSignatureParsing() {
        // TODO: Finish EVMFunctionSignatureParsing
//        for nextTest in testData {
//            nextTest.runTest()
//        }
    }

    private let testData: [TestData] = [
        .init(
            functionName: "depositToken(uint256 _amount, address _module, address _inputToken, address _owner, address _witness, bytes _data, bytes32 _secret)",
            input: "0x486046a800000000000000000000000000000000000000000000001b1ae4d6e2ef500000000000000000000000000000b7499a92fc36e9053a4324affae59d333635d9c300000000000000000000000055d398326f99059ff775485246999027b31979550000000000000000000000000f19af7e10354ec2dc3243eb20f39ebfdc86470e00000000000000000000000061fe0f138b860a7aaa0ae86fc0856917b0bb398800000000000000000000000000000000000000000000000000000000000000e067656c61746f6e6574776f726b245470281f255b8adf968bf12666c58df388dc00000000000000000000000000000000000000000000000000000000000000600000000000000000000000007130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c000000000000000000000000000000000000000000000000004aef5726a2ea8c00000000000000000000000088f8ccc064ba2d39cf08d57b6e7504a7b6be8e4e",
            expectedMethodName: "depositToken",
            expectedArguments: [
                .init(name: "amount", value: .uint256(value: UInt128(stringLiteral: "500000"))),
                .init(name: "module", value: .address(value: "b7499a92fc36e9053a4324affae59d333635d9c3")),
                .init(name: "inputToken", value: .address(value: "55d398326f99059ff775485246999027b3197955")),
                .init(name: "owner", value: .address(value: "0f19af7e10354ec2dc3243eb20f39ebfdc86470e")),
                .init(name: "witness", value: .address(value: "61fe0f138b860a7aaa0ae86fc0856917b0bb3988")),
                .init(name: "data", value: .bytes(value: "67656c61746f6e6574776f726b245470281f255b8adf968bf12666c58df388dc00000000000000000000000000000000000000000000000000000000000000600000000000000000000000007130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c000000000000000000000000000000000000000000000000004aef5726a2ea8c000000000000000000000000".data(using: .utf8)!)),
                .init(name: "secret", value: .address(value: "88f8ccc064ba2d39cf08d57b6e7504a7b6be8e4e")),
            ])
    ]
}

private struct TestData {
    let functionName: String
    let input: String
    let expectedMethodName: String
    let expectedArguments: [EVMArgument]

    func runTest(file: StaticString = #filePath, line: UInt = #line) {
        let txn = testTxn
        XCTAssertEqual(txn.methodName, expectedMethodName, file: file, line: line)

        let txnArgs = txn.functionArguments
        XCTAssertEqual(txnArgs.count, expectedArguments.count, file: file, line: line)
        guard txnArgs.count == expectedArguments.count else { return }

        for (offset, txnArg) in txnArgs.enumerated() {
            let expectedArg = expectedArguments[offset]

            XCTAssertEqual(txnArg.name, expectedArg.name, file: file, line: line)
            XCTAssertEqual(txnArg.value, expectedArg.value, file: file, line: line)
        }
    }

    private var testTxn: TestTransaction {
        .init(functionName: functionName, input: input)
    }
}

extension EVMArgumentValue: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch lhs {
        case .uint256(let lhsValue):
            if case EVMArgumentValue.uint256(let rhsValue) = rhs {
                return lhsValue == rhsValue
            } else {
                return false
            }
        case .address(let lhsValue):
            if case EVMArgumentValue.address(let rhsValue) = rhs {
                return lhsValue == rhsValue
            } else {
                return false
            }
        case .bytes(let lhsValue):
            if case EVMArgumentValue.bytes(let rhsValue) = rhs {
                return lhsValue == rhsValue
            } else {
                return false
            }
        }
    }
}

private struct TestTransaction: EVMNormalTransaction {
    let methodId: String = ""
    let input: String
    let hash: String = ""
    let fromContract: (any CryptoContract)? = nil
    let toContract: (any CryptoContract)? = nil
    let amount: CryptoAmount = .zero
    let timeStamp: Date = .init()
    let transactionId: String = ""
    let gas: Int? = nil
    let gasPrice: CryptoAmount? = nil
    let gasUsed: CryptoAmount? = nil
    let successful: Bool = true
    let functionName: String?
    let type: String? = nil

    init(functionName: String, input: String) {
        self.functionName = functionName
        self.input = input
    }

    init(from decoder: Decoder) throws {
        fatalError()
    }

    func encode(to encoder: Encoder) throws {
        fatalError()
    }
}
