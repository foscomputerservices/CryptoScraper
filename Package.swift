// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "CryptoScraper",
    platforms: [
        .macOS(.v13),
        .iOS(.v15)
        // .linux()
    ],
    products: [
        .library(
            name: "CryptoScraper",
            targets: ["CryptoScraper"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/oscbyspro/AwesomeNumbersKit.git", from: "0.3.4"),
        .package(url: "https://github.com/foscomputerservices/FOSUtilities.git", branch: "main")
    ],
    targets: [
        .target(
            name: "CryptoScraper",
            dependencies: [
                .byName(name: "AwesomeNumbersKit"),
                .product(name: "FOSFoundation", package: "FOSUtilities")
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
