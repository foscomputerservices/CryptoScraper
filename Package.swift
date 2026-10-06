// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CryptoScraper",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0"),
        .macCatalyst("26.0"),
        .tvOS("26.0"),
        .watchOS("26.0")
        // .linux()
    ],
    products: [
        .library(
            name: "CryptoScraper",
            targets: ["CryptoScraper"]
        ),
        .library(
            name: "CryptoTesting",
            targets: ["CryptoTesting"]
        ),
        .library(
            name: "CryptoAsset",
            targets: ["CryptoAsset"]
        ),
        .library(
            name: "CryptoExchange",
            targets: ["CryptoExchange"]
        ),
        .library(
            name: "CryptoHyperliquid",
            targets: ["CryptoHyperliquid"]
        ),
        .library(
            name: "CryptoKraken",
            targets: ["CryptoKraken"]
        ),
        .library(
            name: "CryptoOHLCV",
            targets: ["CryptoOHLCV"]
        ),
        .library(
            name: "CryptoReference",
            targets: ["CryptoReference"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Boilertalk/Web3.swift.git", .upToNextMajor(from: "0.8.3")),
        .package(url: "https://github.com/foscomputerservices/FOSUtilities.git", from: "0.20.0"),
        // CryptoHyperliquid alone: secp256k1 and Keccak-256 for the agent's signature (AR33)
        .package(url: "https://github.com/Boilertalk/secp256k1.swift.git", from: "0.1.7"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.1"),
        // CryptoKraken on Linux: SHA-256 and HMAC-SHA512 (CryptoKit's API) where CryptoKit is absent
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"5.0.0"),
        // Test-only: the two-driver encoding test of CryptoAssetTests
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "4.119.0")),
        .package(url: "https://github.com/vapor/fluent.git", .upToNextMajor(from: "4.12.0")),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", .upToNextMajor(from: "4.8.0")),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", .upToNextMajor(from: "2.10.0"))
//        .package(path: "../FOSUtilities")
    ],
    targets: [
        .target(
            name: "CryptoAsset",
            dependencies: [
                .product(name: "FOSFoundation", package: "FOSUtilities")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CryptoAssetTests",
            dependencies: [
                .byName(name: "CryptoAsset"),
                .product(name: "FOSFoundation", package: "FOSUtilities"),
                .product(name: "FOSTesting", package: "FOSUtilities"),
                .product(name: "FOSTestingVapor", package: "FOSUtilities"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "CryptoExchange",
            dependencies: [
                .byName(name: "CryptoAsset"),
                .product(name: "FOSFoundation", package: "FOSUtilities")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CryptoExchangeTests",
            dependencies: [
                .byName(name: "CryptoExchange"),
                .byName(name: "CryptoAsset"),
                .product(name: "FOSFoundation", package: "FOSUtilities"),
                .product(name: "FOSTesting", package: "FOSUtilities")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "CryptoOHLCV",
            dependencies: [
                .byName(name: "CryptoAsset"),
                .byName(name: "CryptoExchange"),
                .product(name: "FOSFoundation", package: "FOSUtilities")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CryptoOHLCVTests",
            dependencies: [
                .byName(name: "CryptoOHLCV"),
                .byName(name: "CryptoAsset"),
                .byName(name: "CryptoExchange"),
                .byName(name: "CryptoReference"),
                .product(name: "FOSFoundation", package: "FOSUtilities"),
                .product(name: "FOSTesting", package: "FOSUtilities")
            ],
            exclude: ["Behavioral/README.md", "Behavioral/BehavioralAssumptions.md"],
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "CryptoHyperliquid",
            dependencies: [
                .byName(name: "CryptoExchange"),
                .byName(name: "CryptoOHLCV"),
                .byName(name: "CryptoAsset"),
                .product(name: "FOSFoundation", package: "FOSUtilities"),
                .product(name: "secp256k1", package: "secp256k1.swift"),
                .product(name: "CryptoSwift", package: "CryptoSwift")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CryptoHyperliquidTests",
            dependencies: [
                .byName(name: "CryptoHyperliquid"),
                .byName(name: "CryptoExchange"),
                .byName(name: "CryptoOHLCV"),
                .byName(name: "CryptoAsset"),
                .product(name: "FOSFoundation", package: "FOSUtilities"),
                .product(name: "FOSTesting", package: "FOSUtilities")
            ],
            resources: [.copy("Resources/Hyperliquid"), .process("Resources/hyperliquid-signing-vectors.json")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "CryptoKraken",
            dependencies: [
                .byName(name: "CryptoExchange"),
                .byName(name: "CryptoOHLCV"),
                .byName(name: "CryptoAsset"),
                .product(name: "FOSFoundation", package: "FOSUtilities"),
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CryptoKrakenTests",
            dependencies: [
                .byName(name: "CryptoKraken"),
                .byName(name: "CryptoExchange"),
                .byName(name: "CryptoOHLCV"),
                .byName(name: "CryptoAsset"),
                .product(name: "FOSFoundation", package: "FOSUtilities"),
                .product(name: "FOSTesting", package: "FOSUtilities")
            ],
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "CryptoReference",
            dependencies: [
                .byName(name: "CryptoAsset"),
                .product(name: "FOSFoundation", package: "FOSUtilities")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CryptoReferenceTests",
            dependencies: [
                .byName(name: "CryptoReference"),
                .byName(name: "CryptoAsset"),
                .byName(name: "CryptoOHLCV"),
                .product(name: "FOSFoundation", package: "FOSUtilities"),
                .product(name: "FOSTesting", package: "FOSUtilities")
            ],
            exclude: ["Behavioral/README.md", "Behavioral/BehavioralAssumptions.md"],
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CryptoScraperTests",
            dependencies: [
                .byName(name: "CryptoScraper"),
                .product(name: "FOSFoundation", package: "FOSUtilities"),
                .product(name: "FOSTesting", package: "FOSUtilities")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "CryptoScraper",
            dependencies: [
                .product(name: "Web3", package: "Web3.swift"),
                .product(name: "Web3ContractABI", package: "Web3.swift"),
                .product(name: "FOSFoundation", package: "FOSUtilities")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "CryptoTesting",
            dependencies: [
                .byName(name: "CryptoScraper")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
