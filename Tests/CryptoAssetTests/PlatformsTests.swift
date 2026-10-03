// PlatformsTests.swift
//
// Copyright © 2026 FOS Services, LLC. All rights reserved.
//

import Foundation
import Testing

// The platforms: CryptoAsset builds for macOS, iOS, watchOS and tvOS 26 (verified by the xcodebuild runs for the
// three device platforms; this suite runs on macOS), importing Foundation and FOSFoundation only. A source file
// with any other import is a review finding, and this test makes it a red one.

@Suite("Platforms")
struct PlatformsTests {
    @Test func theLibraryImportsFoundationAndFOSFoundationOnly() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // CryptoAssetTests
            .deletingLastPathComponent()      // Tests
            .deletingLastPathComponent()      // the package root
            .appendingPathComponent("Sources/CryptoAsset")
        let files = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)

        let allowed: Set<String> = ["Foundation", "FOSFoundation"]
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
