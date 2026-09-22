// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MVPInstallIdentityKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "MVPInstallIdentityKit",
            targets: ["MVPInstallIdentityKit"]
        )
    ],
    targets: [
        .target(
            name: "MVPInstallIdentityKit",
            dependencies: []
        ),
        .testTarget(
            name: "MVPInstallIdentityKitTests",
            dependencies: ["MVPInstallIdentityKit"]
        )
    ]
)
