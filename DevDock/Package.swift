// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DevDock",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DevDock", targets: ["DevDock"])
    ],
    targets: [
        .executableTarget(
            name: "DevDock",
            path: "DevDock",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DevDockTests",
            dependencies: ["DevDock"],
            path: "Tests"
        )
    ]
)
