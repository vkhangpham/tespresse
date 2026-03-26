// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TesPresse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "TesPresse",
            targets: ["TesPresse"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TesPresse",
            path: "Sources/TesPresse"
        )
    ]
)
