// PlatformsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation
import Testing

// The platforms: CryptoCoinbase builds for macOS, iOS, watchOS and tvOS 26, verified by
//   xcodebuild build -scheme CryptoCoinbase -destination 'generic/platform=watchOS'   (and iOS, tvOS)
// and imports only what it needs (OQ-S46): the base library, CryptoOHLCV for the exchange's market name, CryptoAsset,
// Foundation, FoundationNetworking (Linux only), FOSFoundation, and "CryptoKit", "Crypto".

@Suite("Platforms")
struct PlatformsTests {
    @Test func thePlugInImportsOnlyWhatItNeeds() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/CryptoCoinbase")
        let files = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)
        let allowed: Set<String> = ["CryptoExchange", "CryptoOHLCV", "CryptoAsset", "Foundation", "FoundationNetworking", "FOSFoundation", "CryptoKit", "Crypto"]
        for file in files {
            for line in try String(contentsOf: file, encoding: .utf8).split(separator: "\n") {
                let words = line.split(separator: " ")
                guard let index = words.firstIndex(of: "import"), words[..<index].allSatisfy({ $0.hasPrefix("@") }), index + 1 < words.count else { continue }
                #expect(allowed.contains(String(words[index + 1])), "\(file.lastPathComponent) imports \(words[index + 1])")
            }
        }
    }
}
