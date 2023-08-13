// EVMNormalTransaction.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
import Web3
import Web3ContractABI

public protocol EVMNormalTransaction: CryptoTransaction {
    /// The EVM MethodId
    var methodId: String { get }

    /// The stringified version of ``methodId``
    var methodName: String { get }

    /// A type-safe version of ``functionName``
    var functionArguments: [EVMArgument] { get }

    /// The EVM function input
    var input: String { get }
}

public enum EVMArgumentValue: Codable {
    case uint256(value: UInt128) // TODO: Support UInt256+Codable
    case address(value: String)
    case bytes(value: Data)
}

public struct EVMArgument: Codable {
    public let name: String
    public let value: EVMArgumentValue

    public init(name: String, value: EVMArgumentValue) {
        self.name = name
        self.value = value
    }
}

public extension EVMNormalTransaction {
    // depositToken(uint256 _amount, address _module, address _inputToken, address _owner, address _witness, bytes _data, bytes32 _secret)

    var methodName: String {
        guard let functionName else {
            return ""
        }

        let regex = try! NSRegularExpression(pattern: "([a-z,A-Z,_)]+)", options: [])
        let nsString = functionName as NSString
        let matches = regex.matches(in: functionName, options: [], range: NSMakeRange(0, nsString.length)) // swiftlint:disable:this legacy_constructor
        guard matches.count > 0, let match = matches.first else {
            return ""
        }

        return nsString.substring(with: match.range)
    }

    var functionArguments: [EVMArgument] {
//        let decoder = ABIDecoder(contractABI: contractAbi)
//      let decodedData = try decoder.decodeInput(input, functionName: functionName)
//        web3TxnObject.
        functionArguments2
    }

    var functionArguments2: [EVMArgument] {
        let skipOffset = 10 + 58
        var input: NSString = (input as NSString).substring(from: skipOffset) as NSString

        return funcSignature.reduce([EVMArgument]()) { result, nextArg in
            var result = result

            let len = Int(nextArg.type.charLen(buff: input as String))
            let argValue = input.substring(to: len)
            let envArgument = nextArg.type.evmArgument(name: nextArg.name, value: argValue)
            result.append(envArgument)

            input = input.substring(from: len) as NSString

            return result
        }
    }
}

private extension EVMNormalTransaction {
    private var web3ArgTypes: [SolidityType] {
        funcSignature.map { arg in
            arg.type.solidityType
        }
    }

    private var funcSignatureBlock: String {
        guard let functionName else { return "" }

        let regex = try! NSRegularExpression(pattern: "\\((.+)*\\)", options: [])
        let nsString = functionName as NSString
        let matches = regex.matches(in: functionName, options: [], range: NSMakeRange(0, nsString.length))

        guard matches.count > 0, let match = matches.first else {
            return ""
        }

        return nsString.substring(with: match.range)
    }

    private var funcSignature: [(name: String, type: EVMArgumentType)] {
        guard let functionName = functionName?
            .replacingOccurrences(of: "\(methodName)", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        else {
            return []
        }

        let regex = try! NSRegularExpression(pattern: "(([^\\s]+)\\s_*([^,]+)),*", options: [])
        let nsString = functionName as NSString
        let matches = regex.matches(in: functionName, options: [], range: NSMakeRange(0, nsString.length))

        guard matches.count > 0 else {
            return []
        }

        return matches.reduce([(name: String, type: EVMArgumentType)]()) { result, match in
            var result = result

            result.append((
                name: nsString.substring(with: match.range(at: 3)),
                type: .type(for: nsString.substring(with: match.range(at: 2)))
            ))

            return result
        }
    }
}

private enum EVMArgumentType {
    case uint256
    case address
    case bytes
    case bytes32

    var solidityType: SolidityType {
        switch self {
        case .uint256: return .uint256
        case .address: return .address
        case .bytes: return .bytes(length: nil)
        case .bytes32: return .bytes(length: 32)
        }
    }

    func evmArgument(name: String, value: String) -> EVMArgument {
        let typedValue: EVMArgumentValue
        switch self {
        case .uint256:
            let value = value.trimmingCharacters(in: zeroCharSet)
            typedValue = .uint256(value: UInt128(stringLiteral: value))
        case .address: typedValue = .address(value: value)
        case .bytes: typedValue = .bytes(value: value.data(using: .utf8)!)
        case .bytes32: typedValue = .bytes(value: value.data(using: .utf8)!)
        }

        return .init(name: name, value: typedValue)
    }

    var skipChars: UInt {
        if case Self.bytes = self {
            return Self.uint256.charLen(buff: "")
        } else {
            return 0
        }
    }

    func charLen(buff: String) -> UInt {
        switch self {
        case .uint256: return 6 // 64
        case .address: return 40
        case .bytes:
            // The first 64 chars are a UInt256 for the byte buffer
            let buffSizeStr = String(buff.prefix(64))
            let badChars = CharacterSet.decimalDigits.inverted
            guard !buffSizeStr.unicodeScalars.contains(where: { badChars.contains($0) }) else {
                return 0
            }
            let buffLen = UInt128(stringLiteral: buffSizeStr)
            return UInt(buffLen) + 64
        case .bytes32: return 40
        }
    }

    var zeroCharSet: CharacterSet {
        var zeroCharSet = CharacterSet()
        zeroCharSet.insert("0")
        return zeroCharSet
    }
}

private extension EVMArgumentType {
    static func type(for string: String) -> Self {
        switch string {
        case "uint256": return .uint256
        case "address": return .address
        case "bytes": return .bytes
        case "bytes32": return .bytes32
        default:
            fatalError("Unknown EVM Argument Type: \(string)")
        }
    }
}
