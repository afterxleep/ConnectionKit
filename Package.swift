// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectionKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ConnectionKit",
            targets: ["ConnectionKit"]),
    ],
    dependencies: [       
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.2")
    ],
    targets: [
        .target(
            name: "ConnectionKit",
            dependencies: [
                .product(
                    name: "Dependencies", 
                    package: "swift-dependencies", 
                    condition: .when(platforms: [.iOS, .macOS])
                )
            ]),
        .testTarget(
            name: "ConnectionKitTests",
            dependencies: ["ConnectionKit"]),
    ]
) 
