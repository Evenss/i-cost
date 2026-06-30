// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TokenCostBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TokenCostBar", targets: ["TokenCostBar"]),
        .library(name: "TokenCostBarCore", targets: ["TokenCostBarCore"])
    ],
    targets: [
        .target(
            name: "TokenCostBarCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "TokenCostBar",
            dependencies: ["TokenCostBarCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TokenCostBarCoreTests",
            dependencies: ["TokenCostBarCore"]
        )
    ]
)
