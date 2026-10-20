// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HarborIOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "HarborIOS", targets: ["HarborIOS"])
    ],
    targets: [
        .target(
            name: "HarborIOS",
            path: "Sources/HarborIOS"
        )
    ]
)
