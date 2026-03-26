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
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.2.4")
    ],
    targets: [
        .executableTarget(
            name: "TesPresse",
            path: "Sources/TesPresse",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TesPresseTests",
            dependencies: [
                "TesPresse",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/TesPresseTests"
        )
    ]
)
