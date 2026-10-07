// PlatformsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation
import Testing

// The platforms: CryptoOHLCV and CryptoReference build for macOS, iOS, watchOS and tvOS 26, verified by
//   xcodebuild build -scheme CryptoOHLCV -destination 'generic/platform=watchOS'   (and iOS, tvOS; and CryptoReference)
// and import CryptoAsset, Foundation, FoundationNetworking (Linux only) and FOSFoundation only; CryptoOHLCV also imports
// CryptoExchange, the clients' base library, for the one parse of the wire's number text, and (step 4a of the identity
// PR, design § 1.3's second placement) CryptoScraper, whose protocols its exchange chains conform to, with the standard
// library's Synchronization for the exchange scanners' Mutex.

@Suite("Platforms")
struct PlatformsTests {
    @Test(arguments: ["CryptoOHLCV", "CryptoReference"])
    func theLibraryImportsOnlyItsDeclaredDependencies(library: String) throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // CryptoOHLCVTests
            .deletingLastPathComponent()      // Tests
            .deletingLastPathComponent()      // the package root
            .appendingPathComponent("Sources/\(library)")
        let files = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)

        var allowed: Set<String> = ["CryptoAsset", "Foundation", "FoundationNetworking", "FOSFoundation"]
        if library == "CryptoOHLCV" {
            allowed.formUnion(["CryptoExchange", "CryptoScraper", "Synchronization"])
        }
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.split(separator: "\n") {
                let words = line.split(separator: " ")
                guard let importIndex = words.firstIndex(of: "import"),
                      words[..<importIndex].allSatisfy({ $0.hasPrefix("@") }),
                      importIndex + 1 < words.count
                else { continue }
                // A scoped import ("import struct CryptoAsset.AssetInstance") names its module before the point.
                let kinds: Set<Substring> = ["struct", "class", "enum", "protocol", "typealias", "func", "var", "let"]
                let named = kinds.contains(words[importIndex + 1]) && importIndex + 2 < words.count
                    ? words[importIndex + 2] : words[importIndex + 1]
                let module = String(named.split(separator: ".")[0])
                #expect(allowed.contains(module), "\(file.lastPathComponent) imports \(module)")
            }
        }
    }
}
