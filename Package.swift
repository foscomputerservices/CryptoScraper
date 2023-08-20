// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "CryptoScraper",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
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
        .package(url: "https://github.com/oscbyspro/AwesomeNumbersKit.git", from: "0.3.4"),
        .package(url: "https://github.com/Boilertalk/Web3.swift.git", from: "0.8.3"),
        .package(url: "https://github.com/foscomputerservices/FOSUtilities.git", branch: "main")
//        .package(path: "../FOSUtilities")
    ],
    targets: [
        .target(
            name: "CryptoScraper",
            dependencies: [
                .byName(name: "AwesomeNumbersKit"),
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
