// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Updater",
    platforms: [
        .macOS(.v10_13),
    ],
    products: [
        .library(
            name: "Updater",
            targets: ["Updater"]
        ),
    ],
    targets: [
        .target(
            name: "Updater",
            dependencies: []
        ),
        .testTarget(
            name: "UpdaterTests",
            dependencies: ["Updater"]
        ),
    ]
)
