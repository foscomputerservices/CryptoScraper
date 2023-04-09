// CryptoAmountTests.swift
//
// Copyright © 2023 FOS Services, LLC. All rights reserved.
//

import CryptoScraper
import FOSTesting
import XCTest

final class CryptoAmountTests: XCTestCase {
    func testCodable() throws {
        try FOSAssertCodable(CryptoAmount.self)
    }
}
