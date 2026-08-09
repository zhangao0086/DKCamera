// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "DKCamera",
    platforms: [.iOS(.v8)],
    products: [
        .library(
            name: "DKCamera",
            targets: ["DKCamera"]
        )
    ],
    dependencies: [],
    version: "1.6.8",
    targets: [
        .target(
            name: "DKCamera",
            dependencies: [],
            path: "DKCamera"
        )
    ]
)