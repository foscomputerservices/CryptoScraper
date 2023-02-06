// FoundationDataFetch.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum DataFetchError: Error {
    case message(_ message: String)
    case badStatus(_ httpStatusCode: Int)
}

final class FoundationDataFetch {
    private let urlSession: URLSession

    static let `default`: FoundationDataFetch = .init(urlSession: FoundationDataFetch.UrlSession())

    func fetch<ResultValue: Decodable>(_ url: URL) async throws -> ResultValue {
        try await fetch(url.absoluteString)
    }

    func fetch<ResultValue: Decodable>(_ urlStr: String) async throws -> ResultValue {
        // urlSession.data NYI in Linux foundation
//        guard let url = URL(string: urlStr) else {
//            throw DataFetchError.message("Unable to convert \(urlStr) to URL???")
//        }
//
//        let data = try await urlSession.data(from: url).0
//
//        return try data.fromJSON()
        guard let url = URL(string: urlStr) else {
            throw DataFetchError.message("Unable to convert \(urlStr) to URL???")
        }

        return try await withCheckedThrowingContinuation { continuation in
            urlSession
                .dataTask(with: url) { data, _, e in
                    var result: ResultValue?
                    var error: DataFetchError?

                    if let data {
                        do {
                            if ResultValue.self is String.Type {
                                result = String(data: data, encoding: .utf8) as? ResultValue
                            } else if ResultValue.self is String?.Type {
                                result = String(data: data, encoding: .utf8) as? ResultValue
                            } else {
                                result = try data.fromJSON()
                            }
                        } catch let e {
                            error = .message(e.localizedDescription)
                        }
                    } else if let e {
                        error = .message(e.localizedDescription)
                    } else {
                        error = DataFetchError.message("Unable to retrieve data, unknown error")
                    }

                    if let result {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: error!)
                    }
                }
                .resume()
        }
    }

    func send<ResultValue: Decodable>(data: Data, to urlStr: String, httpMethod: String, callback: @escaping (Result<ResultValue, DataFetchError>) -> Void) {
        guard let url = URL(string: urlStr) else {
            callback(.failure(.message("Unable to convert \(urlStr) to URL???")))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = httpMethod
        urlRequest.httpBody = data
        urlRequest.setValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")

        urlSession
            .dataTask(with: urlRequest) { data, response, error in
                Self.completionHandler(
                    responseData: data,
                    response: response,
                    error: error,
                    callback: callback
                )
            }
            .resume()
    }

    // MARK: Initialization Methods

    init(urlSession: URLSession) {
        self.urlSession = urlSession
    }

    static func UrlSession(forUserToken: String? = nil) -> URLSession {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.allowsCellularAccess = true
        sessionConfig.isDiscretionary = false

        return URLSession(configuration: sessionConfig)
    }
}

private extension FoundationDataFetch {
    private static func completionHandler<ResultValue: Decodable>(responseData: Data?, response: URLResponse?, error: Error?, callback: (Result<ResultValue, DataFetchError>) -> Void) {
        let httpResponse: HTTPURLResponse
        let checkedResponse = Self.checkResponse(response: response, error: error)

        if let error = checkedResponse.1 {
            callback(.failure(error))
            return
        } else if let resp = checkedResponse.0 {
            httpResponse = resp
        } else {
            callback(.failure(.message("One of response or error should have been set!")))
            return
        }

        if let mimeType = httpResponse.mimeType, mimeType == "application/json" {
            if let data = responseData {
                do {
                    callback(.success(try data.fromJSON()))
                } catch let e {
                    callback(.failure(.message(e.localizedDescription)))
                }
            } else {
                callback(.failure(.message("Response data was nil")))
            }
        } else {
            callback(.failure(.message("Unknown mime type: \(String(describing: httpResponse.mimeType))")))
        }
    }

    private static func checkResponse(response: URLResponse?, error: Swift.Error?) -> (HTTPURLResponse?, DataFetchError?) {
        if let error {
            return (nil, .message(error.localizedDescription))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return (nil, .message("Expected to receive an 'HTTPURLResponse', but received '\(String(describing: type(of: response.self)))'"))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            return (nil, .badStatus(httpResponse.statusCode))
        }

        return (httpResponse, nil)
    }
}
