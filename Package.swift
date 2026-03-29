// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "TempureAPP",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TempureAPP",
            targets: ["TempureAPP"]
        ),
    ],
    targets: [
        .target(
            name: "TempureAPP",
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "TempureAPPTests",
            dependencies: ["TempureAPP"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
