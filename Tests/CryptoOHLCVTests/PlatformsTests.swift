// PlatformsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation
import Testing

// The platforms: CryptoOHLCV and CryptoReference build for macOS, iOS, watchOS and tvOS 26, verified by
//   xcodebuild build -scheme CryptoOHLCV -destination 'generic/platform=watchOS'   (and iOS, tvOS; and CryptoReference)
// and import CryptoAsset, Foundation, FoundationNetworking (Linux only) and FOSFoundation only; CryptoOHLCV also imports
// CryptoExchange, the clients' base library, for the one parse of the wire's number text.

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
            allowed.insert("CryptoExchange")
        }
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
