// PlatformsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation
import Testing

// The platforms: CryptoExchange builds for macOS, iOS, watchOS and tvOS 26, verified by
//   xcodebuild build -scheme CryptoExchange -destination 'generic/platform=watchOS'   (and iOS, tvOS)
// and imports CryptoAsset, Foundation, FoundationNetworking (Linux only) and FOSFoundation only (OQ-S46: the base
// library of the exchange protocols links nothing of any one exchange).

@Suite("Platforms")
struct PlatformsTests {
    @Test func theBaseLibraryImportsOnlyItsDeclaredDependencies() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // CryptoExchangeTests
            .deletingLastPathComponent()      // Tests
            .deletingLastPathComponent()      // the package root
            .appendingPathComponent("Sources/CryptoExchange")
        let files = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)

        let allowed: Set<String> = ["CryptoAsset", "Foundation", "FoundationNetworking", "FOSFoundation"]
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.split(separator: "\n") {
                let words = line.split(separator: " ")
                guard let importIndex = words.firstIndex(of: "import"),
                      words[..<importIndex].allSatisfy({ $0.hasPrefix("@") }),
                      importIndex + 1 < words.count
                else { continue }
                let module = String(words[importIndex + 1])
                #expect(allowed.contains(module), "\(file.lastPathComponent) imports \(module)")
            }
        }
    }
}
