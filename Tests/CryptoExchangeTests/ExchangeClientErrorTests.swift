// ExchangeClientErrorTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

@testable import CryptoExchange
import CryptoAsset
import FOSFoundation
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking  // Linux: HTTPURLResponse, URLSession and friends live here
#endif
import Testing

// The owner's ruling of 2026-10-06 ("yes, one shared error type"): C30's ExchangeClientError, and the one reading
// of a failed request every client shares.

@Suite("C30: the shared ExchangeClientError")
struct ExchangeClientErrorTests {
    private func read(_ error: any Error, translating: (any Error) -> ExchangeClientError? = { _ in nil }) -> ExchangeClientError? {
        ExchangeClientError.mapping(error, translating: translating) as? ExchangeClientError
    }

    @Test func aRetryAfterFromTheFetchIsRateLimitedWithItsWait() {
        #expect(read(DataFetchError.retryAfter(.seconds(7))) == .rateLimited(retryAfter: .seconds(7)))
    }

    @Test func aBadCredentialStatusIsUnauthorized() {
        #expect(read(DataFetchError.badStatus(httpStatusCode: 401)) == .unauthorized(text: "HTTP 401"))
        #expect(read(DataFetchError.badStatus(httpStatusCode: 403)) == .unauthorized(text: "HTTP 403"))
    }

    @Test func anyOtherStatusIsRefusedWithItsStatusAsTheCode() {
        #expect(read(DataFetchError.badStatus(httpStatusCode: 500)) == .refused(code: "500", text: "HTTP 500"))
    }

    @Test func aBodyThatDidNotDecodeIsMalformed() {
        let failure = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "no"))
        guard case .malformedResponse = read(DataFetchError.decoding(error: failure, responseData: Data())) else {
            Issue.record("a decode failure was not malformedResponse")
            return
        }
        guard case .malformedResponse = read(DataFetchError.noDataReceived) else {
            Issue.record("an empty answer was not malformedResponse")
            return
        }
        guard case .malformedResponse = read(AmountError.malformedText("sixty-four thousand")) else {
            Issue.record("a number that is not a number was not malformedResponse")
            return
        }
    }

    @Test func aTransportFailureIsUnreachableWithTheTransportsText() {
        let failure = URLError(.timedOut)
        #expect(read(failure) == .unreachable(text: failure.localizedDescription))
    }

    // An answer that disagrees with the statement (an undeclared instance, the units check's changed decimals) is the
    // exchange's word refused, never a transport failure, whichever client met it
    @Test func aStatementThatDisagreesIsRefusedNamingItNeverUnreachable() {
        let instance = AssetInstance.stub()
        for statement in [AssetRegistryError.decimalsChanged(instance), .undeclaredInstance(instance)] {
            #expect(read(statement) == .refused(code: nil, text: String(describing: statement)))
        }
    }

    @Test func theExchangesOwnReadingComesFirstAndASharedErrorPassesThrough() {
        #expect(read(URLError(.timedOut), translating: { _ in .refused(code: "X", text: "y") }) == .refused(code: "X", text: "y"))
        #expect(read(ExchangeClientError.notOffered(member: "transfer")) == .notOffered(member: "transfer"))
    }

    @Test func aCancellationIsNeverAnExchangeError() {
        #expect(ExchangeClientError.mapping(CancellationError()) is CancellationError)
    }
}
