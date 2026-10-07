// Rippled.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import FOSFoundation
import Foundation

/// A ``CryptoScanner`` implementation for a public rippled server's JSON-RPC, `s1.ripple.com:51234`, keyless
///
/// Reads XRP: an account's balance (`account_info`) and its transactions (`account_tx`). An issued token's balance
/// is not read.
public struct Rippled: CryptoScanner, Sendable {
    // MARK: CryptoScanner Protocol

    public typealias Contract = XRPLedgerContract

    /// Ripple's public full-history server
    public static let endPoint: URL = .init(string: "https://s1.ripple.com:51234/")!

    /// "rippled"
    public let userReadableName: String = "rippled"

    public init() {}
}

public enum RippledResponseError: Error {
    /// The request failed for some unknown reason, see *error*
    case requestFailed(_ error: String)

    /// The given contract id is unknown
    case unknownContract(_ contract: String)

    /// An issued token's balance is not read by this scanner, only XRP's
    case unknownToken

    public var localizedDescription: String {
        switch self {
        case .requestFailed(let error):
            return "The request failed: \(error)"
        case .unknownContract(let contractId):
            return "The contract id \(contractId) is unknown."
        case .unknownToken:
            return "Unable to read an issued token's balance on the XRP Ledger; only XRP's is read"
        }
    }
}

extension Rippled {
    /// One rippled JSON-RPC call: `method` with its one parameter object, posted to ``endPoint``
    static func call<Result: Decodable & Sendable>(_ method: String, _ params: [String: Any]) async throws -> Result {
        let body = try JSONSerialization.data(withJSONObject: [
            "method": method, "params": [params]
        ] as [String: Any])
        let response: Response<Result> = try await DataFetch<URLSession>.default.send(
            data: body, to: endPoint, httpMethod: "POST",
            headers: [(field: "Content-Type", value: "application/json")], locale: nil
        )
        return try response.value()
    }

    /// A rippled answer, `{ "result": … }`: the result, or its `status` "error", thrown in the server's words
    struct Response<Result: Decodable & Sendable>: Decodable, Sendable {
        let result: Envelope

        struct Envelope: Decodable, Sendable {
            let status: String?
            let error: String?
            let errorMessage: String?
            let value: Result?

            private enum CodingKeys: String, CodingKey {
                case status
                case error
                case errorMessage = "error_message"
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.status = try container.decodeIfPresent(String.self, forKey: .status)
                self.error = try container.decodeIfPresent(String.self, forKey: .error)
                self.errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
                self.value = error == nil ? try Result(from: decoder) : nil
            }
        }

        func value() throws -> Result {
            if let error = result.error {
                throw RippledResponseError.requestFailed([error, result.errorMessage].compactMap { $0 }.joined(separator: ": "))
            }
            guard let value = result.value else {
                throw RippledResponseError.requestFailed(result.status ?? "no result")
            }
            return value
        }
    }
}
