// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FocusTodo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FocusTodo", targets: ["FocusTodo"])
    ],
    targets: [
        .executableTarget(
            name: "FocusTodo",
            path: "Sources/FocusTodo",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
