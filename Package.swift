// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Reachable",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Reachable",
            targets: ["Reachable"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        .target(
            name: "Reachable",
            dependencies: []),
        .testTarget(
            name: "ReachableTests",
            dependencies: ["Reachable"]),
    ]
) 