// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Ihya",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "IhyaCore", targets: ["IhyaCore"]),
        .executable(name: "ihya", targets: ["IhyaCLI"]),
        .executable(name: "IhyaApp", targets: ["IhyaApp"])
    ],
    targets: [
        .target(
            name: "IhyaCore",
            path: "Sources/IhyaCore"
        ),
        .executableTarget(
            name: "IhyaCLI",
            dependencies: ["IhyaCore"],
            path: "Sources/IhyaCLI"
        ),
        .executableTarget(
            name: "IhyaApp",
            dependencies: ["IhyaCore"],
            path: "Sources/IhyaApp"
        ),
        .testTarget(
            name: "IhyaTests",
            dependencies: ["IhyaCore"],
            path: "Tests/IhyaTests"
        )
    ]
)
