// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "InstallIdentityKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "InstallIdentityKit",
            targets: ["InstallIdentityKit"]
        )
    ],
    targets: [
        .target(
            name: "InstallIdentityKit",
            dependencies: []
        ),
        .testTarget(
            name: "InstallIdentityKitTests",
            dependencies: ["InstallIdentityKit"]
        )
    ]
)
