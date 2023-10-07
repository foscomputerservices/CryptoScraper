// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CryptoScraper",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .macCatalyst(.v15),
        .tvOS(.v15),
        // .watchOS(.v7) -- Web3 dependency breaks watchOS
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
        )
    ],
    dependencies: [
        .package(url: "https://github.com/oscbyspro/Numberick.git", .upToNextMajor(from: "0.13.0")),
        .package(url: "https://github.com/Boilertalk/Web3.swift.git", .upToNextMajor(from: "0.8.3")),
        .package(url: "https://github.com/foscomputerservices/FOSUtilities.git", branch: "main")
//        .package(path: "../FOSUtilities")
    ],
    targets: [
        .target(
            name: "CryptoScraper",
            dependencies: [
                .product(name: "Numberick", package: "Numberick"),
                .product(name: "Web3", package: "Web3.swift"),
                .product(name: "Web3ContractABI", package: "Web3.swift"),
                .product(name: "FOSFoundation", package: "FOSUtilities")
            ]
        ),
        .target(
            name: "CryptoTesting",
            dependencies: [
                .byName(name: "CryptoScraper")
            ]
        ),
        .testTarget(
            name: "CryptoScraperTests",
            dependencies: [
                .byName(name: "CryptoScraper"),
                .product(name: "FOSFoundation", package: "FOSUtilities"),
                .product(name: "FOSTesting", package: "FOSUtilities")
            ]
        )
    ]
)
