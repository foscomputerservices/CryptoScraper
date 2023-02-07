// swift-tools-version: 5.7

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
        )
    ],
    dependencies: [
        .package(url: "https://github.com/oscbyspro/AwesomeNumbersKit.git", from: "0.3.4")
    ],
    targets: [
        .target(
            name: "CryptoScraper",
            dependencies: [
                .byName(name: "AwesomeNumbersKit")
            ]
        ),
        .testTarget(
            name: "CryptoScraperTests",
            dependencies: ["CryptoScraper"]
        )
    ]
)
